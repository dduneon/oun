import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { dayDiff, kstDateOnly } from '../common/time';
import { sportToStat, statLevel } from './leveling';
import { computeMood } from './mood';

const DAY_MS = 86_400_000;
/** 보호권: 연속 기록 7일마다 1개, 최대 2개까지 보유. */
export const PROTECTOR_EVERY = 7;
export const PROTECTOR_MAX = 2;

const PROTECTED_TITLE = '기록 보호권이 연속 기록을 지켰어요';
const protectedBody = (days: number) => `${days}일 쉬어 간 자리를 보호권이 메웠어요. 오늘도 같이 움직여 봐요!`;

/**
 * 운동 1건이 검증됐을 때 캐릭터 스탯·스트릭·mood를 갱신하는 도메인 로직.
 * 항상 상위 트랜잭션(tx) 안에서 호출된다.
 */
@Injectable()
export class GameService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * 기록에서 스탯·스트릭·mood를 다시 계산한다. 날짜를 소급 입력하거나 수정해도
   * 기록 순서에 영향받지 않는 파생값.
   * - 운동한 날은 스트릭 +1, 휴식일·보호권이 메운 날은 끊기지 않게 잇기만 한다.
   * - 먼저 어제까지 빠진 날을 보호권으로 메운다([settleStreak]).
   * - 스트릭이 7의 배수를 새로 넘기면 보호권을 1개 준다(최대 2개, 7일에 한 번).
   */
  async rebuildWorkouts(tx: Prisma.TransactionClient, userId: string, now = new Date()) {
    const protectedDays = await this.settleStreak(tx, userId, now);
    const before = await tx.streak.findUnique({ where: { userId } });

    const rows = await tx.workoutLog.findMany({ where: { userId, verifyStatus: 'verified' }, orderBy: { performedAt: 'asc' } });
    const [rests, guards] = await Promise.all([
      tx.restDay.findMany({ where: { userId }, select: { date: true, createdAt: true }, orderBy: { date: 'asc' } }),
      tx.protectedDay.findMany({ where: { userId }, select: { date: true } }),
    ]);
    const stats = { endurance: 0, strength: 0, agility: 0, balance: 0 };
    // 날짜(KST 자정) → 운동한 날인지(true) / 이어 주기만 하는 날인지(false)
    const days = new Map<number, boolean>();
    for (const row of rows) {
      stats[sportToStat(row.sport)] += Math.max(1, Math.floor(row.durationSec / 60));
      days.set(kstDateOnly(row.performedAt).getTime(), true);
    }
    for (const { date } of [...rests, ...guards]) {
      const key = kstDateOnly(date).getTime();
      if (!days.has(key)) days.set(key, false);
    }

    let current = 0;
    let longest = 0;
    let last: Date | null = null;
    for (const key of [...days.keys()].sort((a, b) => a - b)) {
      const day = new Date(key);
      if (last && dayDiff(day, last) > 1) current = 0;
      if (days.get(key)) current += 1;
      longest = Math.max(longest, current);
      last = day;
    }
    if (last && dayDiff(now, last) > 1) current = 0;

    const protectorEarned = await this.grantProtector(tx, userId, before?.current ?? 0, current, now);
    const lastWorkoutAt = rows.at(-1)?.performedAt ?? null;
    await tx.characterStat.update({ where: { userId }, data: stats });
    await tx.streak.update({ where: { userId }, data: { current, longest, lastActiveDate: last } });
    await tx.characterMood.update({
      where: { userId },
      data: {
        lastWorkoutAt,
        streakActive: current >= 2,
        mood: computeMood(now, lastWorkoutAt, current >= 2, rests.at(-1)?.createdAt),
      },
    });
    return { current, longest, protectorEarned, protectedDays };
  }

  /**
   * 마지막으로 이어진 날과 오늘 사이에 빠진 날(어제까지)을 보호권으로 메운다.
   * 보호권이 모자라면 아무것도 쓰지 않는다(어차피 끊길 스트릭에 낭비하지 않는다).
   * 오늘은 아직 기회가 있으니 메우지 않는다. 메운 날 수를 반환.
   */
  async settleStreak(tx: Prisma.TransactionClient, userId: string, now = new Date()) {
    const streak = await tx.streak.findUnique({ where: { userId } });
    if (!streak?.lastActiveDate || streak.current === 0) return 0;
    const missed = dayDiff(now, streak.lastActiveDate) - 1;
    if (missed <= 0) return 0;
    const guard = await tx.streakProtector.findUnique({ where: { userId } });
    if (!guard || guard.count < missed) return 0;

    const dates = Array.from({ length: missed }, (_, i) => new Date(streak.lastActiveDate!.getTime() + (i + 1) * DAY_MS));
    // 동시 요청이 같은 날을 메우면 한쪽은 0건 → 보호권도 그만큼만 쓴다.
    const { count } = await tx.protectedDay.createMany({
      data: dates.map((date) => ({ userId, date })),
      skipDuplicates: true,
    });
    if (count === 0) return 0;
    await tx.streakProtector.update({ where: { userId }, data: { count: { decrement: count } } });
    await tx.notification.create({
      data: {
        userId,
        type: 'streak_protected',
        title: PROTECTED_TITLE,
        body: protectedBody(count),
      },
    });
    return count;
  }

  /** 스트릭이 7의 배수를 새로 넘겼으면 보호권 1개. 보유 상한·7일 간격으로 되풀이 지급을 막는다. */
  private async grantProtector(
    tx: Prisma.TransactionClient,
    userId: string,
    prev: number,
    next: number,
    now: Date,
  ) {
    if (Math.floor(next / PROTECTOR_EVERY) <= Math.floor(prev / PROTECTOR_EVERY)) return false;
    const guard = await tx.streakProtector.findUnique({ where: { userId } });
    if (!guard || guard.count >= PROTECTOR_MAX) return false;
    if (guard.lastGrantedAt && dayDiff(now, guard.lastGrantedAt) < PROTECTOR_EVERY) return false;
    await tx.streakProtector.update({
      where: { userId },
      data: { count: { increment: 1 }, lastGrantedAt: now },
    });
    return true;
  }

  /**
   * 조회 시점 정리: 빠진 날을 보호권으로 메우거나, 끊긴 스트릭을 0으로 내린다.
   * 홈·마이 진입(GET /me, /character/mood)에서 부른다. 메운 날 수를 반환.
   */
  async refreshStreak(userId: string, now = new Date()) {
    const streak = await this.prisma.streak.findUnique({ where: { userId } });
    if (!streak?.lastActiveDate || streak.current === 0) return 0;
    if (dayDiff(now, streak.lastActiveDate) <= 1) return 0;
    const result = await this.prisma.$transaction((tx) => this.rebuildWorkouts(tx, userId, now));
    // 알림함 행은 트랜잭션 안에서 남겼고, 푸시는 커밋 후에 보낸다.
    if (result.protectedDays > 0) {
      this.notifications.pushLater(userId, {
        title: PROTECTED_TITLE,
        body: protectedBody(result.protectedDays),
        data: { type: 'streak_protected' },
      });
    }
    return result.protectedDays;
  }

  /** GET /character — 종목별 스탯 + 레벨. */
  async character(userId: string) {
    const stat = await this.prisma.characterStat.findUnique({ where: { userId } });
    const s = stat ?? { endurance: 0, strength: 0, agility: 0, balance: 0 };
    return {
      stats: {
        endurance: { points: s.endurance, level: statLevel(s.endurance) },
        strength: { points: s.strength, level: statLevel(s.strength) },
        agility: { points: s.agility, level: statLevel(s.agility) },
        balance: { points: s.balance, level: statLevel(s.balance) },
      },
    };
  }

  /** GET /character/mood — 현재 시각 기준으로 mood를 재산출해 반환(방치 반영). */
  async mood(userId: string) {
    await this.refreshStreak(userId);
    const now = new Date();
    const [row, rest] = await Promise.all([
      this.prisma.characterMood.findUnique({ where: { userId } }),
      this.prisma.restDay.findFirst({ where: { userId }, orderBy: { date: 'desc' } }),
    ]);
    const restingToday = !!rest && dayDiff(now, rest.date) === 0;
    const mood = computeMood(now, row?.lastWorkoutAt ?? null, row?.streakActive ?? false, rest?.createdAt);
    // 재산출된 값이 다르면 저장(캐시 갱신).
    if (row && row.mood !== mood) {
      await this.prisma.characterMood.update({ where: { userId }, data: { mood } });
    }
    return {
      mood,
      restingToday,
      lastWorkoutAt: row?.lastWorkoutAt ?? null,
      streakActive: row?.streakActive ?? false,
    };
  }
}
