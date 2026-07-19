import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { dayDiff, kstDateOnly } from '../common/time';
import { sportToStat, statLevel } from './leveling';
import { computeMood } from './mood';

/**
 * 운동 1건이 검증됐을 때 캐릭터 스탯·스트릭·mood를 갱신하는 도메인 로직.
 * 항상 상위 트랜잭션(tx) 안에서 호출된다.
 */
@Injectable()
export class GameService {
  constructor(private readonly prisma: PrismaService) {}

  /** 검증된 운동 반영: 스탯 증가 + 스트릭 갱신 + mood 재계산. 갱신된 스트릭을 반환. */
  async applyWorkout(
    tx: Prisma.TransactionClient,
    userId: string,
    workout: { sport: string; durationSec: number; performedAt: Date },
  ) {
    const minutes = Math.max(1, Math.floor(workout.durationSec / 60));

    // 1) 스탯 경험치(분) 누적
    const statKey = sportToStat(workout.sport);
    await tx.characterStat.update({
      where: { userId },
      data: { [statKey]: { increment: minutes } },
    });

    // 2) 스트릭 갱신 (KST 날짜 단위)
    const streak = await tx.streak.findUnique({ where: { userId } });
    const today = kstDateOnly(workout.performedAt);
    let current = streak?.current ?? 0;
    if (!streak?.lastActiveDate) {
      current = 1;
    } else {
      const diff = dayDiff(workout.performedAt, streak.lastActiveDate);
      if (diff === 0) {
        current = streak.current; // 오늘 이미 반영됨 — 유지
      } else if (diff === 1) {
        current = streak.current + 1;
      } else {
        current = 1; // 하루 이상 걸렀으면 리셋 (보호권 자동적용은 다음 단계)
      }
    }
    const longest = Math.max(streak?.longest ?? 0, current);
    await tx.streak.update({
      where: { userId },
      data: { current, longest, lastActiveDate: today },
    });

    // 3) mood 재계산 (방금 운동 → energetic)
    const streakActive = current >= 2;
    const mood = computeMood(workout.performedAt, workout.performedAt, streakActive);
    await tx.characterMood.update({
      where: { userId },
      data: { mood, lastWorkoutAt: workout.performedAt, streakActive },
    });

    return { current, longest };
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
    const row = await this.prisma.characterMood.findUnique({ where: { userId } });
    const mood = computeMood(new Date(), row?.lastWorkoutAt ?? null, row?.streakActive ?? false);
    // 재산출된 값이 다르면 저장(캐시 갱신).
    if (row && row.mood !== mood) {
      await this.prisma.characterMood.update({ where: { userId }, data: { mood } });
    }
    return {
      mood,
      lastWorkoutAt: row?.lastWorkoutAt ?? null,
      streakActive: row?.streakActive ?? false,
    };
  }
}
