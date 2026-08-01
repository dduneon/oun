// 운영 시드 진입점 — 정의(상점/퀘스트/업적)만 채운다. 데모 유저는 넣지 않는다.
// 배포 컨테이너에서: node dist/seed/main.js
import { PrismaClient } from '@prisma/client';
import { seedDefinitions } from './definitions';

async function main() {
  const prisma = new PrismaClient();
  try {
    const n = await seedDefinitions(prisma);
    console.log(
      `정의 시드 완료: 아이템 ${n.items} · 퀘스트 ${n.quests} · 업적 ${n.achievements}`,
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
