// 상점 아이템·퀘스트·업적 "정의" 시드. 앱 화면의 목데이터를 그대로 옮겼다.
//
// 이 파일이 src/ 아래 있는 이유: 운영 이미지에는 ts-node가 없어서
// prisma/seed.ts를 돌릴 수 없다. nest build가 dist/seed/*.js로 컴파일해 두면
// 배포 컨테이너에서 `node dist/seed/main.js`로 정의만 채울 수 있다.
// (데모 유저는 개발용이라 prisma/seed.ts에만 남는다)
import { PrismaClient } from '@prisma/client';

export const items = [
  // 의상 (앱 상점 화면 그대로)
  { key: 'hood_daily', category: 'clothing', name: '데일리 후드', price: 120, colorHex: '#D9B38C' },
  { key: 'tee_runner', category: 'clothing', name: '러너 티셔츠', price: 90, colorHex: '#B8C4A9' },
  { key: 'cardigan_knit', category: 'clothing', name: '니트 가디건', price: 210, colorHex: '#E0A9A0' },
  { key: 'windbreaker', category: 'clothing', name: '바람막이', price: 180, colorHex: '#A9BBD0' },
  { key: 'fleece_vest', category: 'clothing', name: '후리스 조끼', price: 150, colorHex: '#D6C08A' },
  { key: 'track_jacket', category: 'clothing', name: '트랙 자켓', price: 240, colorHex: '#C9A9CE', rarity: 'rare' },
  // 헤어
  { key: 'hair_bob', category: 'hair', name: '단정 단발', price: 100, colorHex: '#C8A27A' },
  { key: 'hair_ponytail', category: 'hair', name: '포니테일', price: 130, colorHex: '#B98E63' },
  // 소품
  { key: 'cap_sports', category: 'prop', name: '스포츠 캡', price: 80, colorHex: '#A9BBD0' },
  { key: 'towel_gym', category: 'prop', name: '운동 타월', price: 60, colorHex: '#D6C08A' },
  { key: 'earbuds', category: 'prop', name: '무선 이어폰', price: 160, colorHex: '#C9A9CE', rarity: 'rare', hasSpecialFx: true },
  // 가구
  { key: 'mat_yoga', category: 'furniture', name: '요가 매트', price: 110, colorHex: '#B8C4A9' },
  { key: 'plant_small', category: 'furniture', name: '작은 화분', price: 90, colorHex: '#7FA98C' },
  { key: 'rug_round', category: 'furniture', name: '라운드 러그', price: 140, colorHex: '#E0A9A0' },
] as const;

export const quests = [
  // 일일
  { key: 'daily_workout', kind: 'daily', title: '오늘 운동 기록하기', sub: '어떤 운동이든 1회 기록', reward: 20, goal: 1, trigger: 'workout_logged', icon: 'check_circle_outline', sortOrder: 0 },
  { key: 'daily_30min', kind: 'daily', title: '30분 이상 움직이기', sub: '오늘 누적 운동 30분', reward: 30, goal: 30, trigger: 'workout_minutes', icon: 'timer_outlined', sortOrder: 1 },
  { key: 'daily_photo', kind: 'daily', title: '운동 인증 사진 남기기', sub: '기록에 사진 첨부', reward: 15, goal: 1, trigger: 'workout_photo', icon: 'photo_camera_outlined', sortOrder: 2 },
  // 주간
  { key: 'weekly_3_workouts', kind: 'weekly', title: '이번 주 3회 운동', sub: '주간 운동 일수 채우기', reward: 80, goal: 3, trigger: 'workout_logged', icon: 'calendar_month_outlined', sortOrder: 0 },
  { key: 'weekly_cheer', kind: 'weekly', title: '친구에게 응원 보내기', sub: '이번 주 3번 응원하기', reward: 40, goal: 3, trigger: 'cheer_sent', icon: 'favorite_outline', sortOrder: 1 },
  // 도전
  { key: 'challenge_streak_7', kind: 'challenge', title: '7일 연속 기록', sub: '쉬는 날도 휴식으로 기록하면 이어져요', reward: 150, goal: 7, trigger: 'streak_days', icon: 'local_fire_department_outlined', sortOrder: 0 },
  { key: 'challenge_streak_30', kind: 'challenge', title: '30일 연속 기록', sub: '한 달 개근 도전', reward: 500, goal: 30, trigger: 'streak_days', icon: 'local_fire_department', sortOrder: 1 },
] as const;

export const achievements = [
  { key: 'first_step', name: '첫 걸음', condition: '첫 운동 기록', trigger: 'first_workout', threshold: 1, icon: 'directions_walk', sortOrder: 0 },
  { key: 'week_perfect', name: '일주일 개근', condition: '7일 연속 기록', trigger: 'streak_days', threshold: 7, icon: 'local_fire_department', sortOrder: 1 },
  { key: 'morning_person', name: '아침형 인간', condition: '아침 운동 5회', trigger: 'morning', threshold: 5, icon: 'wb_twilight', sortOrder: 2 },
  { key: 'photo_king', name: '인증왕', condition: '인증 사진 10장', trigger: 'photo', threshold: 10, icon: 'photo_camera', sortOrder: 3 },
  { key: 'month_perfect', name: '한 달 개근', condition: '30일 연속 기록', trigger: 'streak_days', threshold: 30, icon: 'calendar_month', sortOrder: 4 },
  { key: 'runner', name: '러너', condition: '누적 러닝 50km', trigger: 'running_distance', threshold: 50000, icon: 'directions_run', sortOrder: 5 },
  { key: 'iron_will', name: '철의 의지', condition: '웨이트 30회', trigger: 'weight_count', threshold: 30, icon: 'fitness_center', sortOrder: 6 },
  { key: 'crew_debut', name: '크루 데뷔', condition: '첫 크루 가입', trigger: 'crew_join', threshold: 1, icon: 'groups', sortOrder: 7 },
  { key: 'cheerleader', name: '응원단장', condition: '응원 100회 보내기', trigger: 'cheer_sent', threshold: 100, icon: 'favorite', sortOrder: 8 },
  { key: 'fashionista', name: '멋쟁이', condition: '아이템 10개 보유', trigger: 'inventory_count', threshold: 10, icon: 'checkroom', sortOrder: 9 },
  { key: 'night_owl', name: '올빼미', condition: '밤 운동 5회', trigger: 'night', threshold: 5, icon: 'nightlight_round', sortOrder: 10 },
  { key: 'hundred_days', name: '백일의 약속', condition: '100일 연속 기록', trigger: 'streak_days', threshold: 100, icon: 'emoji_events', sortOrder: 11 },
] as const;

/** 정의를 upsert로 채운다 — 여러 번 실행해도 안전하고, 값이 바뀌면 갱신된다. */
export async function seedDefinitions(prisma: PrismaClient) {
  for (const it of items) {
    const { key, ...rest } = it;
    await prisma.item.upsert({ where: { key }, create: { key, ...(rest as any) }, update: rest as any });
  }
  for (const q of quests) {
    const { key, ...rest } = q;
    await prisma.questDef.upsert({ where: { key }, create: { key, ...(rest as any) }, update: rest as any });
  }
  for (const a of achievements) {
    const { key, ...rest } = a;
    await prisma.achievementDef.upsert({ where: { key }, create: { key, ...(rest as any) }, update: rest as any });
  }
  return { items: items.length, quests: quests.length, achievements: achievements.length };
}
