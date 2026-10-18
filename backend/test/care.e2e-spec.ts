import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { GameService } from '../src/game/game.service';
import { PrismaService } from '../src/prisma/prisma.service';

/**
 * Care System e2e: 휴식일 선언·보상·잇기, 기록 보호권 지급·자동 사용.
 * 시간이 지나는 상황은 GameService에 `now`를 넘겨 흉내 낸다.
 */
describe('Care System (e2e)', () => {
  let app: INestApplication;
  let game: GameService;
  let prisma: PrismaService;
  const DAY = 86_400_000;
  const stamp = Date.now() % 1e8; // 닉네임 20자 제한

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    game = app.get(GameService);
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  async function login(nickname: string) {
    const res = await request(app.getHttpServer()).post('/auth/dev').send({ nickname }).expect(201);
    const auth = { Authorization: `Bearer ${res.body.accessToken}` };
    const me = await request(app.getHttpServer()).get('/me').set(auth).expect(200);
    return { auth, id: me.body.id as string };
  }

  const workout = (auth: Record<string, string>, daysAgo: number) =>
    request(app.getHttpServer())
      .post('/workouts')
      .set(auth)
      .send({ sport: 'walking', durationSec: 1200, performedAt: new Date(Date.now() - daysAgo * DAY).toISOString() })
      .expect(201);

  it('휴식일: 보상 10코인, 하루 한 번, mood는 쉬는 중', async () => {
    const { auth } = await login(`crest_${stamp}`);
    const before = await request(app.getHttpServer()).get('/care').set(auth).expect(200);
    expect(before.body.restDay).toMatchObject({ today: false, canDeclare: true, usedThisWeek: 0, weeklyLimit: 2 });

    const res = await request(app.getHttpServer()).post('/care/rest-day').set(auth).expect(201);
    expect(res.body.reward).toBe(10);
    expect(res.body.balance).toBe(10);
    expect(res.body.care.restDay).toMatchObject({ today: true, canDeclare: false });

    await request(app.getHttpServer()).post('/care/rest-day').set(auth).expect(409);

    const mood = await request(app.getHttpServer()).get('/character/mood').set(auth).expect(200);
    expect(mood.body.restingToday).toBe(true);
    expect(mood.body.mood).toBe('happy');
  });

  it('휴식일: 오늘 운동했으면 선언할 수 없다', async () => {
    const { auth } = await login(`cworked_${stamp}`);
    await workout(auth, 0);
    const care = await request(app.getHttpServer()).get('/care').set(auth).expect(200);
    expect(care.body.restDay.canDeclare).toBe(false);
    await request(app.getHttpServer()).post('/care/rest-day').set(auth).expect(409);
  });

  it('휴식일은 연속 기록을 끊지 않고 잇기만 한다', async () => {
    const { auth, id } = await login(`cbridge_${stamp}`);
    await workout(auth, 2);
    const last = await workout(auth, 1);
    expect(last.body.streak.current).toBe(2);
    await request(app.getHttpServer()).post('/care/rest-day').set(auth).expect(201);

    // 내일이 되어도(오늘은 휴식일) 스트릭은 2 그대로.
    const tomorrow = new Date(Date.now() + DAY);
    const s = await prisma.$transaction((tx) => game.rebuildWorkouts(tx, id, tomorrow));
    expect(s.current).toBe(2);
  });

  it('보호권: 연속 7일에 1개 받고, 빠진 날을 자동으로 메운다', async () => {
    const { auth, id } = await login(`cguard_${stamp}`);
    let res;
    for (let d = 7; d >= 1; d--) res = await workout(auth, d);
    expect(res!.body.streak.current).toBe(7);
    expect(res!.body.streak.protectorEarned).toBe(true);

    let care = await request(app.getHttpServer()).get('/care').set(auth).expect(200);
    expect(care.body.protectors).toMatchObject({ count: 1, max: 2, nextInDays: 7 });

    // 오늘 운동을 건너뛰고 내일이 되면 → 오늘 하루를 보호권이 메운다.
    const tomorrow = new Date(Date.now() + DAY);
    expect(await game.refreshStreak(id, tomorrow)).toBe(1);
    expect(await game.refreshStreak(id, tomorrow)).toBe(0); // 두 번 쓰지 않는다
    const streak = await prisma.streak.findUnique({ where: { userId: id } });
    expect(streak!.current).toBe(7);
    const guard = await prisma.streakProtector.findUnique({ where: { userId: id } });
    expect(guard!.count).toBe(0);
    const note = await prisma.notification.findFirst({ where: { userId: id, type: 'streak_protected' } });
    expect(note).not.toBeNull();

    // 보호권이 없으면 더 빠졌을 때 끊긴다.
    expect(await game.refreshStreak(id, new Date(Date.now() + 4 * DAY))).toBe(0);
    const broken = await prisma.streak.findUnique({ where: { userId: id } });
    expect(broken!.current).toBe(0);
  });

  it('보호권: 모자라면 쓰지 않고 스트릭만 끊긴다', async () => {
    const { auth, id } = await login(`cshort_${stamp}`);
    for (let d = 7; d >= 1; d--) await workout(auth, d);
    // 보호권 1개로 이틀(오늘·내일)은 못 메운다.
    expect(await game.refreshStreak(id, new Date(Date.now() + 2 * DAY))).toBe(0);
    const guard = await prisma.streakProtector.findUnique({ where: { userId: id } });
    expect(guard!.count).toBe(1);
    const streak = await prisma.streak.findUnique({ where: { userId: id } });
    expect(streak!.current).toBe(0);
  });
});
