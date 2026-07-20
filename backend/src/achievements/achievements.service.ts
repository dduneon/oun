import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

@Injectable()
export class AchievementsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * 유저의 현재 지표를 재계산해 조건을 만족한 미획득 업적을 지급(뱃지만, 코인 없음).
   * 운동/구매 등 이벤트 후 tx 안에서 호출. UNIQUE 제약으로 중복 지급 차단.
   */
  async evaluate(tx: Prisma.TransactionClient, userId: string) {
    const [workouts, inventoryCount, streak, defs, earned, cheerCount, crewCount] =
      await Promise.all([
        tx.workoutLog.findMany({
          where: { userId, verifyStatus: 'verified' },
          select: { sport: true, distanceM: true, photoRef: true, performedAt: true },
        }),
        tx.inventory.count({ where: { userId } }),
        tx.streak.findUnique({ where: { userId } }),
        tx.achievementDef.findMany(),
        tx.userAchievement.findMany({ where: { userId }, select: { achievementDefId: true } }),
        tx.cheer.count({ where: { fromUserId: userId } }),
        tx.crewMember.count({ where: { userId } }),
      ]);

    const kstHour = (d: Date) => new Date(d.getTime() + KST_OFFSET_MS).getUTCHours();
    const metrics: Record<string, number> = {
      first_workout: workouts.length,
      streak_days: streak?.longest ?? 0,
      morning: workouts.filter((w) => kstHour(w.performedAt) < 9).length,
      night: workouts.filter((w) => kstHour(w.performedAt) >= 21).length,
      photo: workouts.filter((w) => !!w.photoRef).length,
      running_distance: workouts
        .filter((w) => w.sport === 'running')
        .reduce((s, w) => s + (w.distanceM ?? 0), 0),
      weight_count: workouts.filter((w) => w.sport === 'weight').length,
      inventory_count: inventoryCount,
      cheer_sent: cheerCount,
      crew_join: crewCount,
    };

    const earnedSet = new Set(earned.map((e) => e.achievementDefId));
    for (const def of defs) {
      if (earnedSet.has(def.id)) continue;
      const value = metrics[def.trigger];
      if (value === undefined) continue; // 정의만 있고 지표 미구현인 트리거는 건너뜀
      if (value >= def.threshold) {
        await tx.userAchievement.create({
          data: { userId, achievementDefId: def.id },
        });
      }
    }
  }

  /** GET /achievements — 전체 정의 + earned 플래그. */
  async list(userId: string) {
    const [defs, earned] = await Promise.all([
      this.prisma.achievementDef.findMany({ orderBy: { sortOrder: 'asc' } }),
      this.prisma.userAchievement.findMany({ where: { userId } }),
    ]);
    const earnedMap = new Map(earned.map((e) => [e.achievementDefId, e.earnedAt]));
    const items = defs.map((d) => ({
      key: d.key,
      name: d.name,
      condition: d.condition,
      icon: d.icon,
      earned: earnedMap.has(d.id),
      earnedAt: earnedMap.get(d.id) ?? null,
    }));
    return { total: items.length, earned: items.filter((i) => i.earned).length, items };
  }
}
