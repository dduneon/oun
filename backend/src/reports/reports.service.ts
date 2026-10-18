import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { dayDiff, kstDayKey, kstMonthKey, kstMonthRange } from '../common/time';

const KST_OFFSET_MS = 9 * 3_600_000;

/** 보상으로 번 코인만 센다(구매·회수는 빼고). */
const EARN_REASONS = ['workout_reward', 'quest_reward', 'achievement', 'rest_day'] as const;

/** KST 시각 → 운동한 때. */
function timeOfDay(d: Date): 'morning' | 'afternoon' | 'evening' | 'night' {
  const h = new Date(d.getTime() + KST_OFFSET_MS).getUTCHours();
  if (h >= 5 && h < 11) return 'morning';
  if (h >= 11 && h < 17) return 'afternoon';
  if (h >= 17 && h < 22) return 'evening';
  return 'night';
}

/** KST 요일, 월=0 … 일=6. */
function weekday(d: Date): number {
  return (new Date(d.getTime() + KST_OFFSET_MS).getUTCDay() + 6) % 7;
}

/** 가장 많이 나온 키(동률이면 먼저 나온 것). 없으면 null. */
function mostFrequent<T>(items: T[]): T | null {
  const counts = new Map<T, number>();
  for (const i of items) counts.set(i, (counts.get(i) ?? 0) + 1);
  let best: T | null = null;
  let bestCount = 0;
  for (const [k, c] of counts) if (c > bestCount) [best, bestCount] = [k, c];
  return best;
}

/**
 * 월말 감성 리포트. 숫자를 줄 세우지 않고 "이번 달 나는 이렇게 움직였다"를 보여 주는 재료.
 * 문구(칭호·한마디)는 앱이 만든다 — 서버는 집계만.
 */
@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async monthly(userId: string, month = kstMonthKey()) {
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) {
      throw new BadRequestException('month는 YYYY-MM 형식이에요');
    }
    const { start, end } = kstMonthRange(month);
    const [y, m] = month.split('-').map(Number);
    const prevMonth = m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
    const prev = kstMonthRange(prevMonth);
    const inMonth = { gte: start, lt: end };

    const [user, workouts, rests, guards, earned, cheers, prevWorkouts] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId }, select: { createdAt: true } }),
      this.prisma.workoutLog.findMany({
        where: { userId, verifyStatus: 'verified', performedAt: inMonth },
        select: { sport: true, durationSec: true, distanceM: true, performedAt: true },
        orderBy: { performedAt: 'asc' },
      }),
      this.prisma.restDay.findMany({ where: { userId, date: inMonth }, select: { date: true } }),
      this.prisma.protectedDay.findMany({ where: { userId, date: inMonth }, select: { date: true } }),
      this.prisma.currencyLedger.aggregate({
        where: { userId, createdAt: inMonth, delta: { gt: 0 }, reason: { in: [...EARN_REASONS] } },
        _sum: { delta: true },
      }),
      this.prisma.cheer.count({ where: { toUserId: userId, createdAt: inMonth } }),
      this.prisma.workoutLog.findMany({
        where: { userId, verifyStatus: 'verified', performedAt: { gte: prev.start, lt: prev.end } },
        select: { performedAt: true },
      }),
    ]);

    const activeDates = [...new Set(workouts.map((w) => kstDayKey(w.performedAt)))].sort();

    // 종목별
    const sports = new Map<string, { count: number; minutes: number }>();
    for (const w of workouts) {
      const s = sports.get(w.sport) ?? { count: 0, minutes: 0 };
      s.count += 1;
      s.minutes += Math.floor(w.durationSec / 60);
      sports.set(w.sport, s);
    }
    const bySport = [...sports.entries()]
      .map(([sport, v]) => ({ sport, ...v }))
      .sort((a, b) => b.minutes - a.minutes || b.count - a.count);

    // 이달 안에서의 최장 연속(휴식일·보호권은 잇기만)
    const days = new Map<string, boolean>();
    for (const d of activeDates) days.set(d, true);
    for (const { date } of [...rests, ...guards]) {
      const key = kstDayKey(date);
      if (!days.has(key)) days.set(key, false);
    }
    let run = 0;
    let longestStreak = 0;
    let last: string | null = null;
    for (const key of [...days.keys()].sort()) {
      if (last && dayDiff(new Date(`${key}T00:00:00+09:00`), new Date(`${last}T00:00:00+09:00`)) > 1) run = 0;
      if (days.get(key)) run += 1;
      longestStreak = Math.max(longestStreak, run);
      last = key;
    }

    const now = new Date();
    const daysInMonth = new Date(Date.UTC(y, m, 0)).getUTCDate();
    return {
      month,
      firstMonth: kstMonthKey(user?.createdAt ?? now),
      isCurrentMonth: month === kstMonthKey(now),
      daysInMonth,
      workoutDays: activeDates.length,
      workouts: workouts.length,
      totalMinutes: workouts.reduce((s, w) => s + Math.floor(w.durationSec / 60), 0),
      totalDistanceM: workouts.reduce((s, w) => s + (w.distanceM ?? 0), 0),
      restDays: rests.length,
      protectedDays: guards.length,
      longestStreak,
      bySport,
      topWeekday: mostFrequent(workouts.map((w) => weekday(w.performedAt))),
      topTimeOfDay: mostFrequent(workouts.map((w) => timeOfDay(w.performedAt))),
      coinsEarned: earned._sum.delta ?? 0,
      cheersReceived: cheers,
      prevWorkoutDays: new Set(prevWorkouts.map((w) => kstDayKey(w.performedAt))).size,
      activeDates,
    };
  }
}
