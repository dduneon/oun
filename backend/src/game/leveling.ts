// 스탯 레벨 산출. 스탯 포인트는 '누적 운동 분(minute)'을 쌓는다.
// 레벨업마다 필요량이 늘어난다(초반 빠르게, 이후 완만).
// Lv.1 시작, 레벨 n→n+1 필요치 = 30 + (n-1)*15 분.

export function statLevel(points: number): number {
  let level = 1;
  let remaining = points;
  let need = 30;
  while (remaining >= need) {
    remaining -= need;
    level += 1;
    need += 15;
  }
  return level;
}

/** 종목 → 주 스탯 키. */
export function sportToStat(sport: string): 'endurance' | 'strength' | 'agility' | 'balance' {
  switch (sport) {
    case 'running':
    case 'walking':
      return 'endurance';
    case 'weight':
      return 'strength';
    case 'cycling':
      return 'agility';
    case 'yoga':
      return 'balance';
    default:
      return 'endurance';
  }
}

/** 검증된 운동 1건의 코인 보상. 기본 15 + 운동 분(최대 45분까지 반영). */
export function workoutReward(durationSec: number): number {
  const minutes = Math.floor(durationSec / 60);
  return 15 + Math.min(minutes, 45);
}
