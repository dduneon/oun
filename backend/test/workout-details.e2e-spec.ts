import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('운동 상세 기록', () => {
  let app: INestApplication;
  let token: string;
  const nickname = `detail_${Date.now().toString().slice(-8)}`;
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    await app.init();
    const res = await request(app.getHttpServer()).post('/auth/dev').send({ nickname }).expect(201);
    token = res.body.accessToken;
  });
  afterAll(async () => {
    await app.get(PrismaService).user.deleteMany({ where: { nickname } });
    await app.close();
  });
  const auth = () => ({ Authorization: `Bearer ${token}` });

  it('세트·날짜·메모 저장, 수정, 선택 값 해제, 삭제를 왕복한다', async () => {
    const performedAt = new Date(Date.now() - 86400000).toISOString();
    const payload = { sport: 'weight', durationSec: 1805, performedAt, calories: 230, effort: 7, note: '마지막 세트 힘들었음', exercises: [{ name: '벤치프레스', sets: [{ weightKg: 60, reps: 10 }, { weightKg: 57.5, reps: 8 }] }] };
    const created = await request(app.getHttpServer()).post('/workouts').set(auth()).send(payload).expect(201);
    const id = created.body.workout.id;
    const rows = await request(app.getHttpServer()).get('/workouts').set(auth()).expect(200);
    const row = rows.body.items.find((w: any) => w.id === id);
    expect(row).toMatchObject({ durationSec: 1805, performedAt, calories: 230, effort: 7, note: payload.note, sets: 2 });
    expect(row.exercises[0].sets.map((s: any) => [s.weightKg, s.reps])).toEqual([[60, 10], [57.5, 8]]);
    const edited = await request(app.getHttpServer()).patch(`/workouts/${id}`).set(auth()).send({ ...payload, calories: null, effort: null, note: '', exercises: [{ name: '스쿼트', sets: [{ weightKg: 80, reps: 5 }] }] }).expect(200);
    expect(edited.body.workout).toMatchObject({ calories: null, effort: null, note: null, sets: 1 });
    expect(edited.body.workout.exercises).toHaveLength(1);
    expect(edited.body.workout.exercises[0].name).toBe('스쿼트');
    await request(app.getHttpServer()).delete(`/workouts/${id}`).set(auth()).expect(200);
    expect(await app.get(PrismaService).workoutExercise.count({ where: { workoutId: id } })).toBe(0);
  });

  it('음수 중량, 빈 운동명, 미래 날짜를 거부한다', async () => {
    for (const extra of [
      { exercises: [{ name: '벤치프레스', sets: [{ weightKg: -1, reps: 10 }] }] },
      { exercises: [{ name: '  ', sets: [{ weightKg: 0, reps: 10 }] }] },
      { performedAt: new Date(Date.now() + 86400000).toISOString() },
    ]) await request(app.getHttpServer()).post('/workouts').set(auth()).send({ sport: 'weight', durationSec: 600, ...extra }).expect(400);
  });

  it('과거 기록 추가 시 최신 활동 날짜를 유지하고 삭제 시 스탯을 복원한다', async () => {
    const server = app.getHttpServer();
    const today = await request(server).post('/workouts').set(auth()).send({ sport: 'running', durationSec: 600 }).expect(201);
    const older = await request(server).post('/workouts').set(auth()).send({ sport: 'running', durationSec: 1200, performedAt: new Date(Date.now() - 3 * 86400000).toISOString() }).expect(201);
    const user = await app.get(PrismaService).user.findUniqueOrThrow({ where: { nickname }, include: { characterMood: true, characterStat: true } });
    expect(user.characterMood!.lastWorkoutAt!.toISOString()).toBe(today.body.workout.performedAt);
    expect(user.characterStat!.endurance).toBe(30);
    await request(server).delete(`/workouts/${older.body.workout.id}`).set(auth()).expect(200);
    const stats = await app.get(PrismaService).characterStat.findUniqueOrThrow({ where: { userId: user.id } });
    expect(stats.endurance).toBe(10);
    const next = await request(server).get('/workouts?offset=1').set(auth()).expect(200);
    expect(next.body.items).toHaveLength(0);
  });
});
