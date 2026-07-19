import { Mood } from '@prisma/client';

/**
 * 마지막 운동 시각·스트릭으로 캐릭터 mood 산출(파생값).
 * 착한 게이미피케이션: 부정 상태는 hungry/sleepy까지. 질병/사망 없음.
 */
export function computeMood(
  now: Date,
  lastWorkoutAt: Date | null,
  streakActive: boolean,
): Mood {
  if (!lastWorkoutAt) return Mood.neutral;
  const hours = (now.getTime() - lastWorkoutAt.getTime()) / 3_600_000;
  if (hours < 6) return Mood.energetic;
  if (hours < 24) return Mood.happy;
  if (hours < 48) return streakActive ? Mood.happy : Mood.neutral;
  if (hours < 72) return Mood.hungry;
  return Mood.sleepy;
}
