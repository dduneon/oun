import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/**
 * 핵심 루프 e2e: 로그인 → 운동(보상) → 지갑/mood → 퀘스트 claim(멱등) → 상점 구매(가드).
 * 실행 전 docker compose up + prisma migrate + seed 필요.
 */
describe('오운 코어 루프 (e2e)', () => {
  let app: INestApplication;
  let token: string;
  const nickname = `e2e_${Date.now()}`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  const auth = () => ({ Authorization: `Bearer ${token}` });

  it('dev 로그인으로 토큰을 발급한다', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname })
      .expect(201);
    expect(res.body.accessToken).toBeDefined();
    token = res.body.accessToken;
  });

  it('신규 유저는 잔액 0, 스트릭 0', async () => {
    const res = await request(app.getHttpServer()).get('/me').set(auth()).expect(200);
    expect(res.body.coin).toBe(0);
    expect(res.body.streak.current).toBe(0);
  });

  it('운동 기록 → 검증·보상·스트릭', async () => {
    const res = await request(app.getHttpServer())
      .post('/workouts')
      .set(auth())
      .send({ sport: 'running', durationSec: 1920, distanceM: 5200, hasPhoto: true })
      .expect(201);
    expect(res.body.verified).toBe(true);
    expect(res.body.reward).toBe(47); // 15 + min(32,45)
    expect(res.body.balance).toBe(47);
    expect(res.body.streak.current).toBe(1);
  });

  it('지갑·mood·캘린더에 반영된다', async () => {
    const wallet = await request(app.getHttpServer()).get('/wallet').set(auth()).expect(200);
    expect(wallet.body.balance).toBe(47);

    const mood = await request(app.getHttpServer()).get('/character/mood').set(auth()).expect(200);
    expect(mood.body.mood).toBe('energetic');

    const cal = await request(app.getHttpServer())
      .get('/workouts/calendar?month=2026-07')
      .set(auth())
      .expect(200);
    expect(cal.body.days.length).toBeGreaterThan(0);
  });

  it('비정상 페이스 운동은 거절된다(보상 없음)', async () => {
    const res = await request(app.getHttpServer())
      .post('/workouts')
      .set(auth())
      .send({ sport: 'running', durationSec: 600, distanceM: 100000 }) // 166 m/s
      .expect(201);
    expect(res.body.verified).toBe(false);
  });

  it('퀘스트 claim은 보상 지급 + 멱등', async () => {
    const list = await request(app.getHttpServer()).get('/quests').set(auth()).expect(200);
    const daily = list.body.daily.find((q: any) => q.key === 'daily_workout');
    expect(daily.state).toBe('claimable');

    const first = await request(app.getHttpServer())
      .post('/quests/daily_workout/claim')
      .set(auth())
      .expect(201);
    expect(first.body.reward).toBe(20);
    expect(first.body.balance).toBe(67);

    const again = await request(app.getHttpServer())
      .post('/quests/daily_workout/claim')
      .set(auth())
      .expect(201);
    expect(again.body.reward).toBe(0); // 멱등: 재지급 없음
    expect(again.body.balance).toBe(67);
  });

  it('상점 구매 → 차감 + 중복/잔액부족 거절', async () => {
    await request(app.getHttpServer())
      .post('/quests/daily_30min/claim')
      .set(auth())
      .expect(201); // +30 → 97

    const buy = await request(app.getHttpServer())
      .post('/shop/orders')
      .set(auth())
      .send({ itemKey: 'tee_runner' })
      .expect(201);
    expect(buy.body.balance).toBe(7); // 97 - 90

    await request(app.getHttpServer())
      .post('/shop/orders')
      .set(auth())
      .send({ itemKey: 'tee_runner' })
      .expect(409); // 중복 보유

    await request(app.getHttpServer())
      .post('/shop/orders')
      .set(auth())
      .send({ itemKey: 'cardigan_knit' })
      .expect(409); // 잔액 부족

    const inv = await request(app.getHttpServer()).get('/inventory').set(auth()).expect(200);
    expect(inv.body.items.map((i: any) => i.key)).toContain('tee_runner');
  });

  it('첫 운동으로 "첫 걸음" 업적을 획득한다', async () => {
    const res = await request(app.getHttpServer()).get('/achievements').set(auth()).expect(200);
    const first = res.body.items.find((a: any) => a.key === 'first_step');
    expect(first.earned).toBe(true);
  });
});
