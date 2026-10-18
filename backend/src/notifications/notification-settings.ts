/** 푸시 수신 설정 분류. 알림 type → 분류. 모르는 type은 분류 없음(항상 보냄). */
export const NOTIFICATION_CATEGORIES = ['friends', 'cheers', 'crew', 'care'] as const;
export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];

export function categoryOf(type: string | undefined): NotificationCategory | null {
  if (!type) return null;
  if (type === 'friend_request' || type === 'friend_accepted') return 'friends';
  if (type === 'cheer') return 'cheers';
  if (type.startsWith('crew_')) return 'crew';
  if (type === 'streak_protected') return 'care';
  return null;
}
