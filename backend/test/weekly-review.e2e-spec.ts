import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { kstWeekStart } from '../src/common/time';

describe('주간 운동 회고', () => {
  let app: INestApplication;
  let token: string;
  let userId: string;
  const nickname = `week_${Date.now().toString().slice(-8)}`;
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    await app.init();
    const response = await request(app.getHttpServer()).post('/auth/dev').send({ nickname }).expect(201);
    token = response.body.accessToken;
    userId = (await app.get(PrismaService).user.findUniqueOrThrow({ where: { nickname } })).id;
  });
  afterAll(async () => {
    await app.get(PrismaService).user.deleteMany({ where: { nickname } });
    await app.close();
  });
  const get = (week?: string) => request(app.getHttpServer()).get('/workouts/weekly-review')
    .query(week ? { week } : {}).set('Authorization', `Bearer ${token}`);

  it('연도를 넘는 KST 주 경계, 중복 날짜, 50건 초과, 반려 기록을 정확히 집계한다', async () => {
    const db = app.get(PrismaService);
    await db.workoutLog.createMany({ data: [
      ...Array.from({ length: 51 }, () => ({ userId, sport: 'running' as const, durationSec: 60,
        performedAt: new Date('2026-01-05T00:00:00+09:00'), verifyStatus: 'verified' as const })),
      { userId, sport: 'weight', durationSec: 600, performedAt: new Date('2026-01-11T23:59:59+09:00'), verifyStatus: 'verified' },
      { userId, sport: 'running', durationSec: 600, performedAt: new Date('2026-01-04T23:59:59+09:00'), verifyStatus: 'verified' },
      { userId, sport: 'running', durationSec: 600, performedAt: new Date('2026-01-12T00:00:00+09:00'), verifyStatus: 'verified' },
      { userId, sport: 'running', durationSec: 3600, performedAt: new Date('2026-01-06T00:00:00+09:00'), verifyStatus: 'rejected' },
    ] });
    const result = await get('2026-01-05').expect(200);
    expect(result.body).toMatchObject({ weekStart: '2026-01-05', weekEnd: '2026-01-11', isCurrentWeek: false,
      current: { days: 2, sessions: 52, minutes: 61 }, previous: { days: 1, sessions: 1, minutes: 10 } });
    expect(result.body.daily).toHaveLength(7);
    expect(result.body.daily[0].sessions).toBe(51);
    expect(result.body.daily[6].minutes).toBe(10);
    expect(result.body.sports[0]).toEqual({ sport: 'running', minutes: 51, sessions: 51 });
    expect((await get('2025-12-29')).body.current.days).toBe(1);
  });

  it('이번 주는 지난주 같은 시점까지 비교하고 빈 주는 0으로 표시한다', async () => {
    const now = new Date();
    const currentStart = kstWeekStart(now);
    const previousCutoff = new Date(now.getTime() - 7 * 86400000);
    await app.get(PrismaService).workoutLog.createMany({ data: [
      { userId, sport: 'running' as const, durationSec: 600, performedAt: new Date(previousCutoff.getTime() - 60000), verifyStatus: 'verified' as const },
      { userId, sport: 'running' as const, durationSec: 1800, performedAt: new Date(previousCutoff.getTime() + 60000), verifyStatus: 'verified' as const },
    ].filter(r => r.performedAt < currentStart) });
    const result = await get().expect(200);
    expect(result.body.comparison).toBe('지난주 같은 시점');
    expect(result.body.previous.minutes).toBe(10);
    const empty = await get('2020-01-06').expect(200);
    expect(empty.body.current).toEqual({ days: 0, sessions: 0, minutes: 0 });
    expect(empty.body.sports).toEqual([]);
  });

  it('날짜 오류, 월요일 외 날짜, 미래 주를 거부한다', async () => {
    for (const week of ['invalid', '2026-02-30', '2026-01-06', '2099-01-05']) {
      await get(week).expect(400);
    }
    await request(app.getHttpServer()).get('/workouts/weekly-review').expect(401);
  });
});
