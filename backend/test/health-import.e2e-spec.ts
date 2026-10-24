import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('건강 앱 운동 가져오기', () => {
  let app: INestApplication;
  let token: string;
  let otherToken: string;
  let userId: string;
  const nickname = `health_${Date.now().toString().slice(-8)}`;
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    await app.init();
    const res = await request(app.getHttpServer()).post('/auth/dev').send({ nickname }).expect(201);
    token = res.body.accessToken;
    const other = await request(app.getHttpServer()).post('/auth/dev').send({ nickname: `${nickname}_b` }).expect(201);
    otherToken = other.body.accessToken;
    userId = (await app.get(PrismaService).user.findUniqueOrThrow({ where: { nickname } })).id;
  });
  afterAll(async () => {
    await app.get(PrismaService).user.deleteMany({ where: { nickname: { in: [nickname, `${nickname}_b`] } } });
    await app.close();
  });
  const payload = (externalId: string) => ({ source: 'healthkit', externalId,
    performedAt: new Date(Date.now() - 3600000).toISOString(), sport: 'running', durationSec: 1800, distanceM: 5000 });
  const create = (data: object, accessToken = token) => request(app.getHttpServer()).post('/workouts')
    .set('Authorization', `Bearer ${accessToken}`).send(data);

  it('동시 재시도도 운동과 보상을 한 번만 생성하고 삭제 후 재수입을 차단한다', async () => {
    const data = payload('same-workout');
    const results = await Promise.all([create(data), create(data)]);
    expect(results.map(r => r.status).sort()).toEqual([201, 409]);
    const id = results.find(r => r.status === 201)!.body.workout.id;
    const db = app.get(PrismaService);
    expect(await db.workoutLog.count({ where: { userId } })).toBe(1);
    expect(await db.currencyLedger.count({ where: { refId: id, reason: 'workout_reward' } })).toBe(1);
    await request(app.getHttpServer()).delete(`/workouts/${id}`).set('Authorization', `Bearer ${token}`).expect(200);
    await create(data).expect(409);
    const states = await request(app.getHttpServer()).get('/workouts/health-imports')
      .set('Authorization', `Bearer ${token}`).expect(200);
    expect(states.body.items).toEqual([{ source: 'healthkit', externalId: 'same-workout', status: 'deleted' }]);
    const others = await request(app.getHttpServer()).get('/workouts/health-imports')
      .set('Authorization', `Bearer ${otherToken}`).expect(200);
    expect(others.body.items).toEqual([]);
    expect(await db.healthWorkoutImport.findFirst({ where: { userId } })).toMatchObject({ workoutId: null });
    const ledger = await db.currencyLedger.findMany({ where: { refId: id } });
    expect(ledger.reduce((sum, row) => sum + row.delta, 0)).toBe(0);
  });

  it('사용자와 플랫폼마다 원본 ID 범위를 분리한다', async () => {
    await create(payload('same-workout'), otherToken).expect(201);
    await create({ ...payload('same-workout'), source: 'health_connect' }).expect(201);
  });

  it('출처 없는 ID와 원본 정보 없는 건강 기록을 거부한다', async () => {
    await create({ sport: 'running', durationSec: 60, externalId: 'orphan' }).expect(400);
    await create({ sport: 'running', durationSec: 60, source: 'healthkit' }).expect(400);
    await create({ ...payload(''), externalId: ' ' }).expect(400);
  });

  it('수정 시 원본 출처 변경을 차단하고 일반 기록은 계속 저장한다', async () => {
    const created = await create({ sport: 'running', durationSec: 60 }).expect(201);
    await request(app.getHttpServer()).patch(`/workouts/${created.body.workout.id}`)
      .set('Authorization', `Bearer ${token}`).send(payload('changed')).expect(400);
  });
});
