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

    // 방금 기록한 운동은 "오늘"이므로 KST 기준 이번 달을 조회해야 한다.
    // (월을 고정하면 달이 바뀌는 순간부터 실패한다)
    const month = new Date(Date.now() + 9 * 3600 * 1000).toISOString().slice(0, 7);
    const cal = await request(app.getHttpServer())
      .get(`/workouts/calendar?month=${month}`)
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
    const counts = { clothing: 5, bottom: 3, shoes: 3, prop: 3, furniture: 0 };
    for (const [category, n] of Object.entries(counts)) {
      const shop = await request(app.getHttpServer())
        .get(`/shop/items?category=${category}`)
        .set(auth())
        .expect(200);
      expect(shop.body.items).toHaveLength(n); // 가구는 상점에서 내렸다
    }
    // 헤어는 성별 전용 — 기본(f) 캐릭터에게는 여자 헤어만 보인다.
    const hair = await request(app.getHttpServer())
      .get('/shop/items?category=hair')
      .set(auth())
      .expect(200);
    expect(hair.body.items.map((i: any) => i.key).sort()).toEqual(['hair_braids', 'hair_ponytail']);

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

    await request(app.getHttpServer())
      .put('/character/equip')
      .set(auth())
      .send({ itemKey: 'tee_runner' })
      .expect(200);
    const equippedInventory = await request(app.getHttpServer())
      .get('/inventory')
      .set(auth())
      .expect(200);
    expect(equippedInventory.body.items.find((i: any) => i.key === 'tee_runner').equipped).toBe(
      true,
    );
    const equippedShopItem = await request(app.getHttpServer())
      .get('/shop/items?category=clothing')
      .set(auth())
      .expect(200);
    expect(equippedShopItem.body.items.find((i: any) => i.key === 'tee_runner').equipped).toBe(
      true,
    );

    await request(app.getHttpServer())
      .delete('/character/equip/clothing')
      .set(auth())
      .expect(200);
    const unequipped = await request(app.getHttpServer())
      .get('/inventory')
      .set(auth())
      .expect(200);
    expect(unequipped.body.items.find((i: any) => i.key === 'tee_runner').equipped).toBe(false);
    // 비어 있는 슬롯 해제도 멱등하게 성공한다
    await request(app.getHttpServer())
      .delete('/character/equip/clothing')
      .set(auth())
      .expect(200);

    await request(app.getHttpServer())
      .post('/shop/orders')
      .set(auth())
      .send({ itemKey: 'mat_yoga' })
      .expect(404); // 상점에서 내린 아이템(가구)은 구매 불가
  });

  it('성별 전용 헤어는 자기 성별 것만 보이고 살 수 있다', async () => {
    const male = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: `m_${Date.now().toString().slice(-9)}`, gender: 'm' })
      .expect(201);
    const maleAuth = { Authorization: `Bearer ${male.body.accessToken}` };
    const hair = await request(app.getHttpServer())
      .get('/shop/items?category=hair')
      .set(maleAuth)
      .expect(200);
    expect(hair.body.items.map((i: any) => i.key).sort()).toEqual(['hair_flick', 'hair_spiky']);
    await request(app.getHttpServer())
      .post('/shop/orders')
      .set(maleAuth)
      .send({ itemKey: 'hair_ponytail' })
      .expect(403);
    await request(app.getHttpServer())
      .post('/shop/orders')
      .set(auth())
      .send({ itemKey: 'hair_spiky' })
      .expect(403); // 여자 캐릭터는 남자 헤어를 못 산다
    for (let i = 0; i < 3; i++) {
      await request(app.getHttpServer())
        .post('/workouts')
        .set(maleAuth)
        .send({ sport: 'running', durationSec: 2700, distanceM: 7000 })
        .expect(201); // +60씩 → 180
    }
    const buy = await request(app.getHttpServer())
      .post('/shop/orders')
      .set(maleAuth)
      .send({ itemKey: 'hair_flick' })
      .expect(201);
    expect(buy.body.balance).toBe(50);
    await request(app.getHttpServer())
      .post('/shop/orders')
      .set(maleAuth)
      .send({ itemKey: 'hair_bob' })
      .expect(404); // 단정 단발은 상점에서 뺐다
  });

  it('첫 운동으로 "첫 걸음" 업적을 획득한다', async () => {
    const res = await request(app.getHttpServer()).get('/achievements').set(auth()).expect(200);
    const first = res.body.items.find((a: any) => a.key === 'first_step');
    expect(first.earned).toBe(true);
  });
});
