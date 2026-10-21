import { Prisma } from '@prisma/client';

/** GET /wallet/history 한 줄. 문구는 앱이 reason·연관 정보로 만든다. */
export interface WalletHistoryEntry {
  id: string;
  delta: number;
  balanceAfter: number;
  reason: string;
  refType: string | null;
  createdAt: Date;
  /** 운동 보상/환불: 종목 (기록이 지워졌으면 null) */
  sport: string | null;
  customSportName: string | null;
  /** 퀘스트 제목 · 아이템 이름 · 크루 이름 */
  title: string | null;
  /** 크루 레벨 보상의 레벨 */
  level: number | null;
}

export const HISTORY_LIMIT = 100;

/**
 * 최근 코인 변동 내역. 원장 행에 refType/refId로 연결된 엔티티를 한 번씩 모아 붙인다.
 * 연관 엔티티가 지워졌어도(운동 삭제·크루 해산) 원장 행은 그대로 보여 준다.
 */
export async function walletHistory(
  client: Prisma.TransactionClient,
  userId: string,
): Promise<WalletHistoryEntry[]> {
  const rows = await client.currencyLedger.findMany({
    where: { userId },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: HISTORY_LIMIT,
  });

  const idsOf = (type: string) => [
    ...new Set(rows.filter((r) => r.refType === type && r.refId).map((r) => r.refId!)),
  ];
  const crewRef = (refId: string) => {
    const i = refId.lastIndexOf(':');
    return { crewId: refId.slice(0, i), level: Number(refId.slice(i + 1)) };
  };

  const [workouts, quests, items, crews] = await Promise.all([
    client.workoutLog.findMany({
      where: { id: { in: idsOf('workout_log') } },
      select: { id: true, sport: true, customSportName: true },
    }),
    client.userQuest.findMany({
      where: { id: { in: idsOf('quest') } },
      select: { id: true, questDef: { select: { title: true } } },
    }),
    client.item.findMany({
      where: { key: { in: idsOf('shop_order') } },
      select: { key: true, name: true },
    }),
    client.crew.findMany({
      where: { id: { in: idsOf('crew_reward').map((r) => crewRef(r).crewId) } },
      select: { id: true, name: true },
    }),
  ]);
  const workoutById = new Map(workouts.map((w) => [w.id, w]));
  const questTitle = new Map(quests.map((q) => [q.id, q.questDef.title]));
  const itemName = new Map(items.map((i) => [i.key, i.name]));
  const crewName = new Map(crews.map((c) => [c.id, c.name]));

  return rows.map((r) => {
    const entry: WalletHistoryEntry = {
      id: r.id,
      delta: r.delta,
      balanceAfter: r.balanceAfter,
      reason: r.reason,
      refType: r.refType,
      createdAt: r.createdAt,
      sport: null,
      customSportName: null,
      title: null,
      level: null,
    };
    if (!r.refId) return entry;
    switch (r.refType) {
      case 'workout_log': {
        const w = workoutById.get(r.refId);
        entry.sport = w?.sport ?? null;
        entry.customSportName = w?.customSportName ?? null;
        break;
      }
      case 'quest':
        entry.title = questTitle.get(r.refId) ?? null;
        break;
      case 'shop_order':
        entry.title = itemName.get(r.refId) ?? null;
        break;
      case 'crew_reward': {
        const { crewId, level } = crewRef(r.refId);
        entry.title = crewName.get(crewId) ?? null;
        entry.level = Number.isFinite(level) ? level : null;
        break;
      }
    }
    return entry;
  });
}
