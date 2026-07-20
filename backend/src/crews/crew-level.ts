// 크루 레벨: 누적 운동 횟수(피드 글 수) 기반. 앱 crew_level.dart와 동일 공식.
// Lv1→2에 40회, 레벨마다 +20회씩 더 필요.

export interface CrewLevelInfo {
  level: number;
  intoLevel: number; // 현재 레벨에서 쌓은 횟수
  levelSpan: number; // 다음 레벨까지 필요한 횟수
  total: number;
}

export function crewLevelOf(total: number): CrewLevelInfo {
  let level = 1;
  let remaining = total;
  let need = 40;
  while (remaining >= need) {
    remaining -= need;
    level += 1;
    need += 20;
  }
  return { level, intoLevel: remaining, levelSpan: need, total };
}

/** 레벨 보상 정의(앱과 동일). coins=0이면 뱃지/해금류. */
export const crewLevelRewards = [
  { level: 2, label: '전원 코인 50', coins: 50 },
  { level: 3, label: '전원 코인 100', coins: 100 },
  { level: 5, label: '크루 전용 뱃지', coins: 0 },
  { level: 7, label: '전원 코인 200', coins: 200 },
  { level: 10, label: '크루 광장 배경 해금', coins: 0 },
] as const;
