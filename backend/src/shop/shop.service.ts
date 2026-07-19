import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ItemCategory } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { AchievementsService } from '../achievements/achievements.service';

@Injectable()
export class ShopService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly achievements: AchievementsService,
  ) {}

  /** GET /shop/items?category= — 유저 보유 여부 포함. */
  async items(userId: string, category?: ItemCategory) {
    const [items, owned] = await Promise.all([
      this.prisma.item.findMany({
        where: category ? { category } : undefined,
        orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }],
      }),
      this.prisma.inventory.findMany({ where: { userId }, select: { itemKey: true } }),
    ]);
    const ownedSet = new Set(owned.map((o) => o.itemKey));
    return {
      items: items.map((it) => ({
        key: it.key,
        category: it.category,
        name: it.name,
        price: it.price,
        rarity: it.rarity,
        hasSpecialFx: it.hasSpecialFx,
        colorHex: it.colorHex,
        owned: ownedSet.has(it.key),
      })),
    };
  }

  /** POST /shop/orders — 잔액 검증 → 원장 차감 → 인벤토리 등록(트랜잭션·멱등). */
  async order(userId: string, itemKey: string) {
    const item = await this.prisma.item.findUnique({ where: { key: itemKey } });
    if (!item) throw new NotFoundException('없는 아이템이에요');

    return this.prisma.$transaction(async (tx) => {
      const already = await tx.inventory.findUnique({
        where: { userId_itemKey: { userId, itemKey } },
      });
      if (already) throw new ConflictException('이미 보유한 아이템이에요');

      // 원장 차감(잔액 부족 시 ledger가 예외). 멱등키로 중복 구매 차단.
      const { balanceAfter } = await this.ledger.append(tx, {
        userId,
        delta: -item.price,
        reason: 'shop_purchase',
        refType: 'shop_order',
        refId: itemKey,
        idempotencyKey: `shop:${userId}:${itemKey}`,
      });

      await tx.shopOrder.create({
        data: {
          userId,
          itemKey,
          price: item.price,
          idempotencyKey: `shop:${userId}:${itemKey}`,
        },
      });
      await tx.inventory.create({ data: { userId, itemKey } });

      // '멋쟁이'(아이템 10개) 등 보유 기반 업적 판정.
      await this.achievements.evaluate(tx, userId);

      return { itemKey, price: item.price, balance: balanceAfter };
    });
  }

  /** GET /inventory. */
  async inventory(userId: string) {
    const rows = await this.prisma.inventory.findMany({
      where: { userId },
      include: { item: true },
      orderBy: { acquiredAt: 'desc' },
    });
    const equipped = await this.prisma.equipped.findMany({ where: { userId } });
    const equippedSet = new Set(equipped.map((e) => e.itemKey));
    return {
      items: rows.map((r) => ({
        key: r.itemKey,
        name: r.item.name,
        category: r.item.category,
        colorHex: r.item.colorHex,
        equipped: equippedSet.has(r.itemKey),
      })),
    };
  }

  /** PUT /character/equip — 보유 확인 후 슬롯에 장착(슬롯당 하나). */
  async equip(userId: string, itemKey: string, slot?: string) {
    const owned = await this.prisma.inventory.findUnique({
      where: { userId_itemKey: { userId, itemKey } },
      include: { item: true },
    });
    if (!owned) throw new BadRequestException('보유하지 않은 아이템이에요');
    const resolvedSlot = slot ?? owned.item.category; // 슬롯 = 카테고리 기본

    await this.prisma.equipped.upsert({
      where: { userId_slot: { userId, slot: resolvedSlot } },
      create: { userId, slot: resolvedSlot, itemKey },
      update: { itemKey },
    });
    return { slot: resolvedSlot, itemKey };
  }
}
