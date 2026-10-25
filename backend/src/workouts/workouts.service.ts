import {
  ForbiddenException,
  ConflictException,
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { GameService } from '../game/game.service';
import { QuestsService } from '../quests/quests.service';
import { AchievementsService } from '../achievements/achievements.service';
import { workoutReward } from '../game/leveling';
import { kstDayKey, kstMonthRange, kstWeekStart } from '../common/time';
import { StorageService } from '../storage/storage.service';
import { CreateWorkoutDto } from './dto';
import { verifyWorkout } from './verify';

const workoutInclude = {
  exercises: { orderBy: { position: 'asc' as const }, include: {
    sets: { orderBy: { position: 'asc' as const } },
  } },
};

function exerciseData(dto: CreateWorkoutDto) {
  if (dto.sport !== 'weight' && dto.exercises?.length) {
    throw new BadRequestException('세트별 기록은 웨이트에서 사용할 수 있어요');
  }
  return (dto.exercises ?? []).map((exercise, position) => {
    if (!exercise.name.trim()) throw new BadRequestException('운동 이름을 입력해 주세요');
    return { name: exercise.name.trim(), position, sets: { create:
      exercise.sets.map((set, position) => ({ ...set, position })),
    } };
  });
}

function checkDate(dto: CreateWorkoutDto) {
  if (dto.performedAt && new Date(dto.performedAt).getTime() > Date.now() + 60000) {
    throw new BadRequestException('미래의 운동은 기록할 수 없어요');
  }
}

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
    private readonly storage: StorageService,
  ) {}

  /** POST /workouts — 기록 제출 → 검증 → (승인 시) 보상·스탯·스트릭·mood·퀘스트·업적. */
  async create(userId: string, dto: CreateWorkoutDto) {
    if (dto.source && dto.source !== 'manual') {
      if (!dto.externalId?.trim() || !dto.performedAt) {
        throw new BadRequestException('건강 앱의 원본 기록 정보가 필요해요');
      }
    } else if (dto.externalId != null) {
      throw new BadRequestException('건강 앱 출처가 필요해요');
    }
    checkDate(dto);
    const exercises = exerciseData(dto);
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
          sets: exercises.length ? dto.exercises!.reduce((n, e) => n + e.sets.length, 0) : dto.sets,
          calories: dto.calories,
          note: dto.note?.trim() || null,
          effort: dto.effort,
          customSportName: dto.customSportName?.trim() || null,
          exercises: { create: exercises },
          photoRef: dto.photoRef,
          source: dto.source ?? 'manual',
          healthImport: dto.externalId ? { create: {
            userId, source: dto.source!, externalId: dto.externalId,
          } } : undefined,
          verifyStatus: status,
          rejectReason: reason,
          verifiedAt: status === 'verified' ? new Date() : null,
          performedAt,
        },
        include: workoutInclude,
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
      const streak = await this.game.rebuildWorkouts(tx, userId);

      // 퀘스트 진행 + 업적 판정
      await this.quests.onWorkout(tx, userId, {
        minutes: Math.floor(dto.durationSec / 60),
        hasPhoto,
        streakCurrent: streak.current,
        performedAt,
      });
      await this.achievements.evaluate(tx, userId);

      return {
        workout,
        verified: true,
        reward,
        balance: balanceAfter,
        streak,
      };
    }).catch((error: unknown) => {
      if (dto.externalId && error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('이미 가져온 운동이에요. 삭제한 기록도 다시 가져올 수 없어요');
      }
      throw error;
    });
  }

  /** DELETE /workouts/:id — 본인 기록 삭제 + 지급됐던 코인 보상 회수.
   *  스탯·스트릭은 재계산한다. 이미 지급된 퀘스트·업적 보상은 유지한다. */
  async remove(userId: string, workoutId: string) {
    const workout = await this.prisma.workoutLog.findUnique({
      where: { id: workoutId },
    });
    if (!workout) throw new NotFoundException('운동 기록을 찾을 수 없어요');
    if (workout.userId !== userId) {
      throw new ForbiddenException('내 기록만 삭제할 수 있어요');
    }

    return this.prisma.$transaction(async (tx) => {
      // 이 운동으로 지급된 원장 합계(보상 + 이후 수정 조정분)를 전부 회수.
      const total = await this.workoutLedgerTotal(tx, workoutId);
      if (total !== 0) {
        await this.ledger.append(tx, {
          userId,
          delta: -total,
          reason: 'refund',
          refType: 'workout_log',
          refId: workoutId,
          idempotencyKey: `workout_refund:${workoutId}`,
          allowNegative: true,
        });
      }
      await tx.workoutLog.delete({ where: { id: workoutId } });
      await this.game.rebuildWorkouts(tx, userId);
      const balance = await this.ledger.balanceOf(userId, tx);
      return { deleted: true, balance };
    });
  }

  /** 이 운동으로 지급된 원장 delta 합계(보상 + 수정 조정 + 회수). */
  private async workoutLedgerTotal(
    tx: Prisma.TransactionClient,
    workoutId: string,
  ) {
    const rows = await tx.currencyLedger.findMany({
      where: { refType: 'workout_log', refId: workoutId },
    });
    return rows.reduce((s, r) => s + r.delta, 0);
  }

  /** PATCH /workouts/:id — 본인 기록 수정. 검증·코인 보상을 다시 계산해 맞춘다.
   *  스탯·스트릭은 재계산한다. 이미 지급된 퀘스트·업적 보상은 유지한다. */
  async update(userId: string, workoutId: string, dto: CreateWorkoutDto) {
    if (dto.externalId != null || dto.source != null) {
      throw new BadRequestException('기록의 원본 출처는 변경할 수 없어요');
    }
    checkDate(dto);
    const exercises = exerciseData(dto);
    const existing = await this.prisma.workoutLog.findUnique({
      where: { id: workoutId },
    });
    if (!existing) throw new NotFoundException('운동 기록을 찾을 수 없어요');
    if (existing.userId !== userId) {
      throw new ForbiddenException('내 기록만 수정할 수 있어요');
    }

    const { status, reason } = verifyWorkout(dto);
    const performedAt = dto.performedAt
      ? new Date(dto.performedAt)
      : existing.performedAt;

    return this.prisma.$transaction(async (tx) => {
      // 코인 정합: 이 운동의 원장 합계를 새 보상과 일치시키는 만큼만 가감.
      const currentTotal = await this.workoutLedgerTotal(tx, workoutId);
      const newReward =
        status === 'verified' ? workoutReward(dto.durationSec) : 0;
      const diff = newReward - currentTotal;
      if (diff !== 0) {
        await this.ledger.append(tx, {
          userId,
          delta: diff,
          reason: diff > 0 ? 'workout_reward' : 'refund',
          refType: 'workout_log',
          refId: workoutId,
          idempotencyKey: `workout_edit:${workoutId}:${Date.now()}`,
          allowNegative: true,
        });
      }

      const updated = await tx.workoutLog.update({
        where: { id: workoutId },
        data: {
          sport: dto.sport,
          durationSec: dto.durationSec,
          distanceM: dto.distanceM ?? null,
          steps: dto.steps ?? null,
          bodyPart: dto.bodyPart ?? null,
          sets: exercises.length ? dto.exercises!.reduce((n, e) => n + e.sets.length, 0) : dto.sets ?? null,
          calories: dto.calories === undefined ? existing.calories : dto.calories,
          note: dto.note === undefined ? existing.note : dto.note?.trim() || null,
          effort: dto.effort === undefined ? existing.effort : dto.effort,
          customSportName: dto.customSportName === undefined ? existing.customSportName : dto.customSportName?.trim() || null,
          exercises: dto.exercises !== undefined || dto.sport !== 'weight'
            ? { deleteMany: {}, create: exercises } : undefined,
          photoRef: dto.photoRef ?? existing.photoRef,
          verifyStatus: status,
          rejectReason: reason ?? null,
          verifiedAt:
            status === 'verified' ? (existing.verifiedAt ?? new Date()) : null,
          performedAt,
        },
        include: workoutInclude,
      });
      await this.game.rebuildWorkouts(tx, userId);
      const balance = await this.ledger.balanceOf(userId, tx);
      return {
        workout: {
          ...updated,
          photoUrl: this.storage.publicUrlFor(updated.photoRef),
        },
        verified: status === 'verified',
        reason,
        reward: newReward,
        balance,
      };
    });
  }

  /** KST Monday-Sunday; current week compares equal elapsed periods. */
  async weeklyReview(userId: string, week?: string) {
    const now = new Date();
    const currentStart = kstWeekStart(now);
    let start = currentStart;
    if (week !== undefined) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(week)) throw new BadRequestException('올바른 주 시작일이 필요해요');
      start = new Date(`${week}T00:00:00+09:00`);
      if (!Number.isFinite(start.getTime()) || kstDayKey(start) !== week ||
          kstWeekStart(start).getTime() !== start.getTime() || start > currentStart) {
        throw new BadRequestException('이번 주 이전의 월요일을 선택해 주세요');
      }
    }
    const dayMs = 86400000;
    const end = new Date(start.getTime() + 7 * dayMs);
    const previousStart = new Date(start.getTime() - 7 * dayMs);
    const isCurrentWeek = start.getTime() === currentStart.getTime();
    const cutoff = isCurrentWeek ? now : end;
    const previousCutoff = new Date(cutoff.getTime() - 7 * dayMs);
    const rows = await this.prisma.workoutLog.findMany({
      where: { userId, verifyStatus: 'verified', performedAt: { gte: previousStart, lt: cutoff } },
      select: { performedAt: true, durationSec: true, sport: true },
    });
    const current = rows.filter(r => r.performedAt >= start);
    const previous = rows.filter(r => r.performedAt < previousCutoff);
    const summarize = (items: typeof rows) => ({
      days: new Set(items.map(r => kstDayKey(r.performedAt))).size,
      sessions: items.length,
      minutes: Math.floor(items.reduce((sum, r) => sum + r.durationSec, 0) / 60),
    });
    const bySport = new Map<string, { sport: string; seconds: number; sessions: number }>();
    for (const row of current) {
      const entry = bySport.get(row.sport) ?? { sport: row.sport, seconds: 0, sessions: 0 };
      entry.seconds += row.durationSec;
      entry.sessions++;
      bySport.set(row.sport, entry);
    }
    const sports = [...bySport.values()].sort((a, b) => b.seconds - a.seconds || a.sport.localeCompare(b.sport))
      .map(({ sport, seconds, sessions }) => ({ sport, minutes: Math.floor(seconds / 60), sessions }));
    const daily = Array.from({ length: 7 }, (_, i) => {
      const date = kstDayKey(new Date(start.getTime() + i * dayMs));
      const items = current.filter(r => kstDayKey(r.performedAt) === date);
      return { date, ...summarize(items), future: date > kstDayKey(now) };
    });
    return { weekStart: kstDayKey(start), weekEnd: kstDayKey(new Date(end.getTime() - 1)),
      isCurrentWeek, comparison: isCurrentWeek ? '지난주 같은 시점' : '이전 주',
      current: summarize(current), previous: summarize(previous), daily, sports };
  }

  async healthImports(userId: string, after?: string) {
    const rows = await this.prisma.healthWorkoutImport.findMany({
      where: { userId, ...(after ? { id: { gt: after } } : {}) },
      orderBy: { id: 'asc' }, take: 201,
      select: { id: true, source: true, externalId: true, workoutId: true },
    });
    const items = rows.slice(0, 200);
    return { items: items.map(r => ({ source: r.source, externalId: r.externalId,
      status: r.workoutId ? 'recorded' : 'deleted' })),
      next: rows.length > 200 ? items[199].id : null };
  }

  /** GET /workouts?from=&to= — 최근 기록 리스트. */
  async list(userId: string, from?: string, to?: string, offset = 0) {
    if (!Number.isInteger(offset) || offset < 0) throw new BadRequestException('잘못된 페이지예요');
    const where: { userId: string; performedAt?: { gte?: Date; lte?: Date } } = { userId };
    if (from || to) {
      where.performedAt = {};
      if (from) where.performedAt.gte = new Date(from);
      if (to) where.performedAt.lte = new Date(to);
    }
    const items = await this.prisma.workoutLog.findMany({
      where,
      orderBy: [{ performedAt: 'desc' }, { id: 'desc' }],
      take: 50,
      skip: offset,
      include: workoutInclude,
    });
    return {
      items: items.map((w) => ({
        ...w,
        photoUrl: this.storage.publicUrlFor(w.photoRef),
      })),
    };
  }

  /** GET /workouts/calendar?month=YYYY-MM — 일별 강도(0~4). */
  async calendar(userId: string, month: string) {
    const { start, end } = kstMonthRange(month);
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
    const { start, end } = kstMonthRange(month);
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
