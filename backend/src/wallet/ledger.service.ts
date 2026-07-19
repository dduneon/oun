import { ConflictException, Injectable } from '@nestjs/common';
import { Prisma, LedgerReason } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface LedgerAppend {
  userId: string;
  delta: number;
  reason: LedgerReason;
  idempotencyKey: string;
  refType?: string;
  refId?: string;
  /** 차감(음수 delta) 시 잔액 부족을 막을지. 기본 true. */
  allowNegative?: boolean;
}

/**
 * 재화 증감의 유일한 창구. 모든 코인 변동은 여기를 거쳐 CurrencyLedger에 append된다.
 * - 멱등키 UNIQUE로 중복 보상/차감 차단.
 * - 잔액 = 최신 balanceAfter. 클라이언트는 절대 계산하지 않는다.
 * tx(트랜잭션 클라이언트)를 받아 상위 도메인 트랜잭션 안에서 원자적으로 동작한다.
 */
@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  /** 현재 잔액(최신 balanceAfter). 원장이 없으면 0. */
  async balanceOf(
    userId: string,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<number> {
    const last = await client.currencyLedger.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return last?.balanceAfter ?? 0;
  }

  /**
   * 원장에 한 줄 append. 멱등키가 이미 있으면 기존 결과를 그대로 반환(중복 무시).
   * 반환: { balanceAfter, applied } — applied=false면 멱등 히트(변동 없음).
   */
  async append(
    tx: Prisma.TransactionClient,
    input: LedgerAppend,
  ): Promise<{ balanceAfter: number; applied: boolean }> {
    // 멱등: 같은 키가 이미 있으면 그 시점 잔액 그대로.
    const existing = await tx.currencyLedger.findUnique({
      where: { idempotencyKey: input.idempotencyKey },
    });
    if (existing) {
      return { balanceAfter: existing.balanceAfter, applied: false };
    }

    const current = await this.balanceOf(input.userId, tx);
    const next = current + input.delta;
    if (next < 0 && input.allowNegative !== true) {
      throw new ConflictException('코인이 부족해요');
    }

    await tx.currencyLedger.create({
      data: {
        userId: input.userId,
        delta: input.delta,
        balanceAfter: next,
        reason: input.reason,
        refType: input.refType,
        refId: input.refId,
        idempotencyKey: input.idempotencyKey,
      },
    });
    return { balanceAfter: next, applied: true };
  }
}
