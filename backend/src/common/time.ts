// 오운은 한국 우선 출시 → 퀘스트 자정 리셋 등은 KST(UTC+9) 기준으로 계산한다.
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** 주어진 시각을 KST 기준 '그 날 00:00(UTC 표현)'으로 절삭. 캘린더/스트릭 날짜 단위 비교용. */
export function kstDateOnly(d: Date): Date {
  const shifted = new Date(d.getTime() + KST_OFFSET_MS);
  const y = shifted.getUTCFullYear();
  const m = shifted.getUTCMonth();
  const day = shifted.getUTCDate();
  // 다시 UTC로 되돌린 자정(=KST 그 날의 시작)을 저장 기준으로 쓴다.
  return new Date(Date.UTC(y, m, day) - KST_OFFSET_MS);
}

/** KST 기준 'YYYY-MM-DD'. 일일 퀘스트 periodKey. */
export function kstDayKey(d: Date): string {
  const shifted = new Date(d.getTime() + KST_OFFSET_MS);
  return shifted.toISOString().slice(0, 10);
}

/** KST 기준 ISO 주(월요일 시작) 'GGGG-Www'. 주간 퀘스트 periodKey. */
export function kstWeekKey(d: Date): string {
  const shifted = new Date(d.getTime() + KST_OFFSET_MS);
  // ISO week 계산
  const date = new Date(
    Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()),
  );
  const dayNum = date.getUTCDay() || 7; // 일=7
  date.setUTCDate(date.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${date.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
}

/** 두 날짜(날짜단위)의 일수 차. */
export function dayDiff(a: Date, b: Date): number {
  return Math.round((kstDateOnly(a).getTime() - kstDateOnly(b).getTime()) / 86400000);
}

/** KST 기준 이번 주 월요일 00:00(UTC 표현). 주간 집계의 시작 경계. */
export function kstWeekStart(d: Date): Date {
  const dayStart = kstDateOnly(d);
  const shifted = new Date(dayStart.getTime() + KST_OFFSET_MS);
  const weekday = shifted.getUTCDay() || 7; // 월=1 … 일=7
  return new Date(dayStart.getTime() - (weekday - 1) * 86400000);
}
