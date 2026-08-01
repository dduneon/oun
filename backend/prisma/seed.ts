// 로컬 개발용 시드 = 정의(src/seed/definitions.ts) + 데모 유저.
// 운영에는 데모 유저를 넣지 않는다 — 배포에서는 `node dist/seed/main.js`가
// 정의만 채운다(이미지에 ts-node가 없어 이 파일은 운영에서 실행되지 않는다).
import { PrismaClient } from '@prisma/client';
import { seedDefinitions } from '../src/seed/definitions';

const prisma = new PrismaClient();

// 데모 유저 — 친구 추가/크루 초대 대상. @nickname으로 검색해 추가한다.
const demoUsers = [
  { nickname: 'jimin', displayName: '지민', gender: 'f' },
  { nickname: 'hyunwoo', displayName: '현우', gender: 'm' },
  { nickname: 'seoyeon', displayName: '서연', gender: 'f' },
  { nickname: 'minjun', displayName: '민준', gender: 'm' },
] as const;

// 데모 유저별 최근 운동(며칠 전, 종목, 분, 부가 지표).
const demoWorkouts: Record<string, Array<{ daysAgo: number; sport: string; minutes: number; distanceM?: number; steps?: number; bodyPart?: string; sets?: number; photo?: boolean }>> = {
  jimin: [
    { daysAgo: 0, sport: 'running', minutes: 32, distanceM: 5200, photo: true },
    { daysAgo: 1, sport: 'running', minutes: 28, distanceM: 4300 },
    { daysAgo: 3, sport: 'yoga', minutes: 40 },
  ],
  hyunwoo: [
    { daysAgo: 0, sport: 'weight', minutes: 48, bodyPart: 'lower', sets: 5 },
    { daysAgo: 1, sport: 'weight', minutes: 45, bodyPart: 'upper', sets: 4 },
    { daysAgo: 2, sport: 'weight', minutes: 50, bodyPart: 'full', sets: 5 },
  ],
  seoyeon: [
    { daysAgo: 1, sport: 'walking', minutes: 58, steps: 8200 },
    { daysAgo: 2, sport: 'walking', minutes: 45, steps: 6400 },
  ],
  minjun: [{ daysAgo: 2, sport: 'cycling', minutes: 55, distanceM: 15000 }],
};

async function seedDemoUsers() {
  for (const du of demoUsers) {
    const exists = await prisma.user.findUnique({ where: { nickname: du.nickname } });
    if (exists) continue;
    const user = await prisma.user.create({
      data: {
        nickname: du.nickname,
        displayName: du.displayName,
        gender: du.gender as any,
        characterStat: { create: {} },
        characterMood: { create: {} },
        streak: { create: {} },
        streakProtector: { create: { count: 0 } },
      },
    });
    const logs = demoWorkouts[du.nickname] ?? [];
    let lastAt: Date | null = null;
    for (const w of logs) {
      const performedAt = new Date(Date.now() - w.daysAgo * 86400000 - 2 * 3600000);
      await prisma.workoutLog.create({
        data: {
          userId: user.id,
          sport: w.sport as any,
          durationSec: w.minutes * 60,
          distanceM: w.distanceM,
          steps: w.steps,
          bodyPart: w.bodyPart as any,
          sets: w.sets,
          photoRef: w.photo ? 'demo' : null,
          source: 'manual',
          verifyStatus: 'verified',
          performedAt,
          verifiedAt: performedAt,
        },
      });
      if (!lastAt || performedAt > lastAt) lastAt = performedAt;
    }
    if (lastAt) {
      await prisma.characterMood.update({
        where: { userId: user.id },
        data: { lastWorkoutAt: lastAt, streakActive: true },
      });
      await prisma.streak.update({
        where: { userId: user.id },
        data: { current: logs.length, longest: logs.length, lastActiveDate: lastAt },
      });
    }
  }
}

async function main() {
  const n = await seedDefinitions(prisma);
  await seedDemoUsers();
  console.log(
    `시드 완료: 아이템 ${n.items} · 퀘스트 ${n.quests} · 업적 ${n.achievements} · 데모유저 ${demoUsers.length}`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
