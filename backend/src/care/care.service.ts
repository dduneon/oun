import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { GameService, PROTECTOR_EVERY, PROTECTOR_MAX } from '../game/game.service';
import { dayDiff, kstDateOnly, kstDayKey, kstWeekStart } from '../common/time';

/** 휴식일: 한 주(KST 월~일)에 2번까지, 소량 보상. */
export const REST_DAY_WEEKLY_LIMIT = 2;
export const REST_DAY_REWARD = 10;

/**
 * Care System — 쉬는 날을 처벌하지 않는 장치들.
 * - 휴식일: 오늘을 공식 휴식일로 선언하면 소량 코인 + 연속 기록이 끊기지 않는다.
 * - 기록 보호권: 빠진 날을 자동으로 메운다(지급·사용은 GameService가 스트릭 계산과 함께).
 */
@Injectable()
export class CareService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly game: GameService,
  ) {}

  /** GET /care — 마이·홈의 휴식일 버튼과 보호권 화면에 필요한 상태. */
  async status(userId: string, now = new Date()) {
    await this.game.refreshStreak(userId, now);
    const today = kstDateOnly(now);
    const [streak, guard, restsThisWeek, workedToday, protectedDays] = await Promise.all([
      this.prisma.streak.findUnique({ where: { userId } }),
      this.prisma.streakProtector.findUnique({ where: { userId } }),
      this.prisma.restDay.findMany({ where: { userId, date: { gte: kstWeekStart(now) } }, select: { date: true } }),
      this.prisma.workoutLog.count({ where: { userId, verifyStatus: 'verified', performedAt: { gte: today } } }),
      this.prisma.protectedDay.findMany({ where: { userId }, orderBy: { date: 'desc' }, take: 5, select: { date: true } }),
    ]);
    const restingToday = restsThisWeek.some((r) => dayDiff(r.date, today) === 0);
    const current = streak?.current ?? 0;
    const count = guard?.count ?? 0;

    let blockedReason: string | null = null;
    if (restingToday) blockedReason = '오늘은 이미 쉬는 날이에요';
    else if (workedToday > 0) blockedReason = '오늘은 벌써 운동했어요';
    else if (restsThisWeek.length >= REST_DAY_WEEKLY_LIMIT) blockedReason = '이번 주 휴식일을 다 썼어요';

    return {
      streak: { current, longest: streak?.longest ?? 0 },
      restDay: {
        today: restingToday,
        canDeclare: blockedReason === null,
        blockedReason,
        usedThisWeek: restsThisWeek.length,
        weeklyLimit: REST_DAY_WEEKLY_LIMIT,
        reward: REST_DAY_REWARD,
      },
      protectors: {
        count,
        max: PROTECTOR_MAX,
        every: PROTECTOR_EVERY,
        // 다음 보호권까지 남은 연속 일수(이미 최대면 null).
        nextInDays: count >= PROTECTOR_MAX ? null : PROTECTOR_EVERY - (current % PROTECTOR_EVERY),
        recentProtectedDates: protectedDays.map((d) => kstDayKey(d.date)),
      },
    };
  }

  /** POST /care/rest-day — 오늘을 휴식일로 선언. 하루 한 번, 운동한 날은 불가. */
  async declareRestDay(userId: string, now = new Date()) {
    const care = await this.status(userId, now);
    if (!care.restDay.canDeclare) throw new ConflictException(care.restDay.blockedReason);

    const balance = await this.prisma.$transaction(async (tx) => {
      const rest = await tx.restDay.create({ data: { userId, date: kstDateOnly(now), rewarded: true } });
      const { balanceAfter } = await this.ledger.append(tx, {
        userId,
        delta: REST_DAY_REWARD,
        reason: 'rest_day',
        refType: 'rest_day',
        refId: rest.id,
        idempotencyKey: `rest_day:${userId}:${kstDayKey(now)}`,
      });
      await this.game.rebuildWorkouts(tx, userId, now);
      return balanceAfter;
    }).catch((e) => {
      // 동시에 두 번 눌러 같은 날 행이 겹친 경우
      if (e?.code === 'P2002') throw new ConflictException('오늘은 이미 쉬는 날이에요');
      throw e;
    });

    return { reward: REST_DAY_REWARD, balance, care: await this.status(userId, now) };
  }
}
