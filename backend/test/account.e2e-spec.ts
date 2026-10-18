import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PushService } from '../src/notifications/push.service';
import { kstMonthKey } from '../src/common/time';

/** 마이 탭: 월말 리포트, 알림 설정, 프로필 수정, 회원 탈퇴. */
describe('리포트·알림 설정·계정 (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  const stamp = Date.now() % 1e8; // 닉네임 20자 제한

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());

  async function login(nickname: string) {
    const res = await http().post('/auth/dev').send({ nickname }).expect(201);
    const auth = { Authorization: `Bearer ${res.body.accessToken}` };
    const me = await http().get('/me').set(auth).expect(200);
    return { auth, id: me.body.id as string };
  }

  it('월말 리포트: 이번 달 기록을 모아 준다', async () => {
    const { auth } = await login(`rep_${stamp}`);
    const now = Date.now();
    // 이번 달 안에 있도록 오늘 기록 2건(러닝·요가)만 남긴다.
    await http().post('/workouts').set(auth)
      .send({ sport: 'running', durationSec: 1800, distanceM: 5000, performedAt: new Date(now).toISOString() }).expect(201);
    await http().post('/workouts').set(auth)
      .send({ sport: 'yoga', durationSec: 600, performedAt: new Date(now - 1000).toISOString() }).expect(201);

    const res = await http().get('/reports/monthly').set(auth).expect(200);
    expect(res.body).toMatchObject({
      month: kstMonthKey(),
      isCurrentMonth: true,
      workoutDays: 1,
      workouts: 2,
      totalMinutes: 40,
      totalDistanceM: 5000,
      longestStreak: 1,
      firstMonth: kstMonthKey(),
    });
    expect(res.body.bySport[0]).toMatchObject({ sport: 'running', count: 1, minutes: 30 });
    expect(res.body.coinsEarned).toBeGreaterThan(0);
    expect(res.body.activeDates).toHaveLength(1);

    const empty = await http().get('/reports/monthly?month=2020-01').set(auth).expect(200);
    expect(empty.body).toMatchObject({ workoutDays: 0, workouts: 0, topWeekday: null, topTimeOfDay: null });
    await http().get('/reports/monthly?month=2020-13').set(auth).expect(400);
  });

  it('알림 설정: 기본은 모두 켜짐, 끈 분류는 푸시를 보내지 않는다', async () => {
    const { auth, id } = await login(`noti_${stamp}`);
    const get = await http().get('/me/notification-settings').set(auth).expect(200);
    expect(get.body).toEqual({ friends: true, cheers: true, crew: true, care: true });

    const put = await http().put('/me/notification-settings').set(auth).send({ cheers: false }).expect(200);
    expect(put.body).toEqual({ friends: true, cheers: false, crew: true, care: true });

    const push = app.get(PushService);
    expect(await push.allowed(id, 'cheer')).toBe(false);
    expect(await push.allowed(id, 'crew_comment')).toBe(true);
    expect(await push.allowed(id, 'something_new')).toBe(true);
  });

  it('프로필: 이름·닉네임을 바꾸고, 겹치거나 형식이 틀리면 막는다', async () => {
    const a = await login(`pa_${stamp}`);
    await login(`pb_${stamp}`);

    const res = await http().patch('/me').set(a.auth).send({ displayName: '  새 이름 ', nickname: `pc_${stamp}` }).expect(200);
    expect(res.body).toMatchObject({ displayName: '새 이름', nickname: `pc_${stamp}` });

    await http().patch('/me').set(a.auth).send({ nickname: `pb_${stamp}` }).expect(409);
    await http().patch('/me').set(a.auth).send({ nickname: 'has space' }).expect(400);
  });

  it('회원 탈퇴: 방장이면 가장 오래된 멤버에게 넘기고, 계정과 기록이 사라진다', async () => {
    const leader = await login(`dl_${stamp}`);
    const member = await login(`dm_${stamp}`);
    const solo = await http().post('/crews').set(leader.auth).send({ name: `혼자${stamp}` }).expect(201);
    const shared = await http().post('/crews').set(leader.auth).send({ name: `함께${stamp}` }).expect(201);
    await prisma.crewMember.create({ data: { crewId: shared.body.id, userId: member.id } });
    await http().post('/workouts').set(leader.auth).send({ sport: 'walking', durationSec: 600 }).expect(201);

    await http().delete('/me').set(leader.auth).expect(200);

    expect(await prisma.user.findUnique({ where: { id: leader.id } })).toBeNull();
    expect(await prisma.workoutLog.count({ where: { userId: leader.id } })).toBe(0);
    expect(await prisma.crew.findUnique({ where: { id: solo.body.id } })).toBeNull();
    const heir = await prisma.crewMember.findUnique({
      where: { crewId_userId: { crewId: shared.body.id, userId: member.id } },
    });
    expect(heir?.role).toBe('leader');
    await http().get('/me').set(leader.auth).expect(404);
  });
});
