import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, QuestDef, QuestKind, QuestState } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { kstDayKey, kstWeekKey } from '../common/time';

export interface WorkoutQuestEvent {
  minutes: number;
  hasPhoto: boolean;
  streakCurrent: number;
}

@Injectable()
export class QuestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  private periodKey(kind: QuestKind, now: Date): string {
    switch (kind) {
      case QuestKind.daily:
        return kstDayKey(now);
      case QuestKind.weekly:
        return kstWeekKey(now);
      default:
        return 'all';
    }
  }

  /** 현재 주기의 UserQuest 행을 보장(없으면 생성). */
  private async ensureRow(
    client: Prisma.TransactionClient | PrismaService,
    userId: string,
    def: QuestDef,
    now: Date,
  ) {
    const periodKey = this.periodKey(def.kind, now);
    return client.userQuest.upsert({
      where: {
        userId_questDefId_periodKey: { userId, questDefId: def.id, periodKey },
      },
      create: { userId, questDefId: def.id, periodKey },
      update: {},
    });
  }

  /** 운동 검증 시 관련 퀘스트 진행도 갱신. tx 안에서 호출. */
  async onWorkout(tx: Prisma.TransactionClient, userId: string, ev: WorkoutQuestEvent) {
    const defs = await tx.questDef.findMany();
    const now = new Date();
    for (const def of defs) {
      let nextProgress: number | null = null;
      const row = await this.ensureRow(tx, userId, def, now);
      switch (def.trigger) {
        case 'workout_logged':
          nextProgress = row.progress + 1;
          break;
        case 'workout_minutes':
          nextProgress = row.progress + ev.minutes;
          break;
        case 'workout_photo':
          if (ev.hasPhoto) nextProgress = row.progress + 1;
          break;
        case 'streak_days':
          // 최고 스트릭 유지(리셋돼도 달성 이력 보존).
          nextProgress = Math.max(row.progress, ev.streakCurrent);
          break;
        default:
          nextProgress = null; // cheer_sent 등은 다음 단계
      }
      if (nextProgress === null) continue;
      const reached = nextProgress >= def.goal;
      await tx.userQuest.update({
        where: { id: row.id },
        data: {
          progress: nextProgress,
          // 이미 claimed면 유지, 아니면 목표 도달 시 claimable.
          state:
            row.state === QuestState.claimed
              ? QuestState.claimed
              : reached
                ? QuestState.claimable
                : QuestState.in_progress,
        },
      });
    }
  }

  /** 응원 보냄 이벤트: cheer_sent 트리거 퀘스트 진행. tx 안에서 호출. */
  async onCheer(tx: Prisma.TransactionClient, userId: string) {
    const defs = await tx.questDef.findMany({ where: { trigger: 'cheer_sent' } });
    const now = new Date();
    for (const def of defs) {
      const row = await this.ensureRow(tx, userId, def, now);
      const nextProgress = row.progress + 1;
      const reached = nextProgress >= def.goal;
      await tx.userQuest.update({
        where: { id: row.id },
        data: {
          progress: nextProgress,
          state:
            row.state === QuestState.claimed
              ? QuestState.claimed
              : reached
                ? QuestState.claimable
                : QuestState.in_progress,
        },
      });
    }
  }

  /** GET /quests — kind별 목록 + 진행/상태. 조회 시 현재 주기 행을 보장. */
  async list(userId: string) {
    const defs = await this.prisma.questDef.findMany({ orderBy: { sortOrder: 'asc' } });
    const now = new Date();
    const rows = await Promise.all(defs.map((def) => this.ensureRow(this.prisma, userId, def, now)));
    const byDefId = new Map(rows.map((r) => [r.questDefId, r]));

    const shape = (def: QuestDef) => {
      const r = byDefId.get(def.id)!;
      return {
        key: def.key,
        kind: def.kind,
        title: def.title,
        sub: def.sub,
        reward: def.reward,
        goal: def.goal,
        icon: def.icon,
        progress: Math.min(r.progress, def.goal),
        state: r.state,
      };
    };

    return {
      daily: defs.filter((d) => d.kind === QuestKind.daily).map(shape),
      weekly: defs.filter((d) => d.kind === QuestKind.weekly).map(shape),
      challenge: defs.filter((d) => d.kind === QuestKind.challenge).map(shape),
    };
  }

  /** POST /quests/:key/claim — claimable → claimed + 코인 보상(멱등). */
  async claim(userId: string, key: string) {
    const def = await this.prisma.questDef.findUnique({ where: { key } });
    if (!def) throw new NotFoundException('없는 퀘스트예요');
    const now = new Date();
    const periodKey = this.periodKey(def.kind, now);

    return this.prisma.$transaction(async (tx) => {
      const row = await tx.userQuest.findUnique({
        where: {
          userId_questDefId_periodKey: { userId, questDefId: def.id, periodKey },
        },
      });
      if (!row || row.state === QuestState.in_progress) {
        throw new BadRequestException('아직 받을 수 없는 퀘스트예요');
      }
      if (row.state === QuestState.claimed) {
        // 멱등: 이미 받음 → 현재 잔액만 반환.
        const balance = await this.ledger.balanceOf(userId, tx);
        return { claimed: true, reward: 0, balance };
      }

      const { balanceAfter } = await this.ledger.append(tx, {
        userId,
        delta: def.reward,
        reason: 'quest_reward',
        refType: 'quest',
        refId: row.id,
        idempotencyKey: `quest:${row.id}`,
      });
      await tx.userQuest.update({
        where: { id: row.id },
        data: { state: QuestState.claimed, claimedAt: new Date() },
      });
      return { claimed: true, reward: def.reward, balance: balanceAfter };
    });
  }
}
