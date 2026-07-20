import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { GameService } from '../game/game.service';
import { QuestsService } from '../quests/quests.service';
import { AchievementsService } from '../achievements/achievements.service';
import { workoutReward } from '../game/leveling';
import { kstDayKey } from '../common/time';
import { CreateWorkoutDto } from './dto';
import { verifyWorkout } from './verify';

/** 하루 총 운동 분 → 캘린더 강도(0~4). 앱 기록 화면 도트와 매핑. */
function intensityOf(minutes: number): number {
  if (minutes <= 0) return 0;
  if (minutes < 20) return 1;
  if (minutes < 40) return 2;
  if (minutes < 70) return 3;
  return 4;
}

@Injectable()
export class WorkoutsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly game: GameService,
    private readonly quests: QuestsService,
    private readonly achievements: AchievementsService,
  ) {}

  /** POST /workouts — 기록 제출 → 검증 → (승인 시) 보상·스탯·스트릭·mood·퀘스트·업적. */
  async create(userId: string, dto: CreateWorkoutDto) {
    const performedAt = dto.performedAt ? new Date(dto.performedAt) : new Date();
    const hasPhoto = dto.hasPhoto === true || !!dto.photoRef;
    const { status, reason } = verifyWorkout(dto);

    return this.prisma.$transaction(async (tx) => {
      const workout = await tx.workoutLog.create({
        data: {
          userId,
          sport: dto.sport,
          durationSec: dto.durationSec,
          distanceM: dto.distanceM,
          steps: dto.steps,
          bodyPart: dto.bodyPart,
          sets: dto.sets,
          calories: dto.calories,
          photoRef: dto.photoRef,
          source: dto.source ?? 'manual',
          verifyStatus: status,
          rejectReason: reason,
          verifiedAt: status === 'verified' ? new Date() : null,
          performedAt,
        },
      });

      if (status === 'rejected') {
        return { workout, verified: false, reason, reward: 0, balance: await this.ledger.balanceOf(userId, tx) };
      }

      // 보상 (멱등키 = 워크아웃 id)
      const reward = workoutReward(dto.durationSec);
      const { balanceAfter } = await this.ledger.append(tx, {
        userId,
        delta: reward,
        reason: 'workout_reward',
        refType: 'workout_log',
        refId: workout.id,
        idempotencyKey: `workout_reward:${workout.id}`,
      });

      // 스탯·스트릭·mood
      const streak = await this.game.applyWorkout(tx, userId, {
        sport: dto.sport,
        durationSec: dto.durationSec,
        performedAt,
      });

      // 퀘스트 진행 + 업적 판정
      await this.quests.onWorkout(tx, userId, {
        minutes: Math.floor(dto.durationSec / 60),
        hasPhoto,
        streakCurrent: streak.current,
      });
      await this.achievements.evaluate(tx, userId);

      return {
        workout,
        verified: true,
        reward,
        balance: balanceAfter,
        streak,
      };
    });
  }

  /** GET /workouts?from=&to= — 최근 기록 리스트. */
  async list(userId: string, from?: string, to?: string) {
    const where: { userId: string; performedAt?: { gte?: Date; lte?: Date } } = { userId };
    if (from || to) {
      where.performedAt = {};
      if (from) where.performedAt.gte = new Date(from);
      if (to) where.performedAt.lte = new Date(to);
    }
    const items = await this.prisma.workoutLog.findMany({
      where,
      orderBy: { performedAt: 'desc' },
      take: 50,
    });
    return { items };
  }

  /** GET /workouts/calendar?month=YYYY-MM — 일별 강도(0~4). */
  async calendar(userId: string, month: string) {
    const { start, end } = monthRange(month);
    const rows = await this.prisma.workoutLog.findMany({
      where: { userId, verifyStatus: 'verified', performedAt: { gte: start, lt: end } },
      select: { performedAt: true, durationSec: true },
    });
    const perDay = new Map<string, number>();
    for (const r of rows) {
      const key = kstDayKey(r.performedAt);
      perDay.set(key, (perDay.get(key) ?? 0) + Math.floor(r.durationSec / 60));
    }
    const days = [...perDay.entries()]
      .map(([date, minutes]) => ({ date, minutes, intensity: intensityOf(minutes) }))
      .sort((a, b) => a.date.localeCompare(b.date));
    return { month, days };
  }

  /** GET /workouts/summary?month=YYYY-MM — 운동한 날/총 시간/최장 연속. */
  async summary(userId: string, month: string) {
    const { start, end } = monthRange(month);
    const [rows, streak] = await Promise.all([
      this.prisma.workoutLog.findMany({
        where: { userId, verifyStatus: 'verified', performedAt: { gte: start, lt: end } },
        select: { performedAt: true, durationSec: true },
      }),
      this.prisma.streak.findUnique({ where: { userId } }),
    ]);
    const days = new Set(rows.map((r) => kstDayKey(r.performedAt)));
    const totalMinutes = rows.reduce((s, r) => s + Math.floor(r.durationSec / 60), 0);
    return {
      month,
      workoutDays: days.size,
      totalMinutes,
      longestStreak: streak?.longest ?? 0,
    };
  }
}

/** 'YYYY-MM' → 해당 월의 [start, end) (KST 자정 경계). */
function monthRange(month: string): { start: Date; end: Date } {
  const [y, m] = month.split('-').map(Number);
  // KST 자정 = UTC 15:00 전날. Date.UTC로 만든 뒤 9시간 당김.
  const start = new Date(Date.UTC(y, m - 1, 1) - 9 * 3600 * 1000);
  const end = new Date(Date.UTC(y, m, 1) - 9 * 3600 * 1000);
  return { start, end };
}
