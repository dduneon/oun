import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/** 코인 내역(GET /wallet/history): 최신순, 운동 종목·휴식일·삭제 회수가 보인다. */
describe('코인 내역 (e2e)', () => {
  let app: INestApplication;
  let token: string;
  const nickname = `wh_${Date.now().toString().slice(-9)}`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    const res = await request(app.getHttpServer()).post('/auth/dev').send({ nickname });
    token = res.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  const auth = () => ({ Authorization: `Bearer ${token}` });

  it('적립·회수가 최신순으로 쌓이고 잔액과 맞는다', async () => {
    const empty = await request(app.getHttpServer()).get('/wallet/history').set(auth()).expect(200);
    expect(empty.body).toEqual({ balance: 0, entries: [] });

    const created = await request(app.getHttpServer())
      .post('/workouts')
      .set(auth())
      .send({ sport: 'running', durationSec: 1500, distanceM: 4000 })
      .expect(201);
    const reward = created.body.reward as number;

    const mid = await request(app.getHttpServer()).get('/wallet/history').set(auth()).expect(200);
    expect(mid.body.entries).toHaveLength(1);
    expect(mid.body.entries[0]).toMatchObject({
      delta: reward,
      balanceAfter: reward,
      reason: 'workout_reward',
      refType: 'workout_log',
      sport: 'running',
    });

    await request(app.getHttpServer())
      .delete(`/workouts/${created.body.workout.id}`)
      .set(auth())
      .expect(200);

    const res = await request(app.getHttpServer()).get('/wallet/history').set(auth()).expect(200);
    expect(res.body.balance).toBe(0);
    expect(res.body.entries.map((e: any) => e.reason)).toEqual(['refund', 'workout_reward']);
    expect(res.body.entries[0]).toMatchObject({ delta: -reward, balanceAfter: 0, sport: null });
  });

  it('인증 없이는 401', async () => {
    await request(app.getHttpServer()).get('/wallet/history').expect(401);
  });
});
