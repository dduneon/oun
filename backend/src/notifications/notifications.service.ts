import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { kstDateOnly } from '../common/time';
import { PushService, PushPayload } from './push.service';

export interface NotificationInput {
  type: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {}

  /**
   * 알림 행 생성. 도메인 트랜잭션 안에서 호출하라고 `tx`를 받는다.
   * **푸시는 여기서 보내지 않는다** — 트랜잭션 안에서 외부 네트워크를 타면
   * 롤백된 알림을 푸시하거나 커밋이 지연될 수 있어서, 커밋 후 [pushLater]로 보낸다.
   */
  async create(
    tx: Prisma.TransactionClient,
    userId: string,
    input: NotificationInput,
  ) {
    return tx.notification.create({
      data: {
        userId,
        type: input.type,
        title: input.title,
        body: input.body,
        data: input.data ?? undefined,
      },
    });
  }

  /**
   * 커밋 후 푸시(fire-and-forget). 푸시 실패가 요청 실패로 번지지 않도록
   * await하지 않고 에러를 삼킨다 — 인앱 알림함이 이미 진실의 원본이다.
   */
  pushLater(userId: string, payload: PushPayload): void {
    void this.push.sendToUser(userId, payload).catch(() => undefined);
  }

  /**
   * 트랜잭션이 없는 호출부용: 알림 생성 + 푸시를 한 번에.
   * 자기 자신에게는 보내지 않는다(내 행동의 알림을 내가 받을 이유가 없다).
   */
  async notify(
    userId: string,
    actorId: string | null,
    input: NotificationInput,
  ): Promise<void> {
    if (actorId && actorId === userId) return;
    await this.create(this.prisma, userId, input);
    this.pushLater(userId, {
      title: input.title,
      body: input.body,
      data: { type: input.type, ...(input.data ?? {}) },
    });
  }

  /**
   * 하루(KST) 상한이 있는 알림을 **트랜잭션 안에서** 만든다.
   *
   * 응원처럼 반복이 자연스럽지만(아침·저녁) 무제한이면 남의 폰에 푸시를
   * 쏟아붓게 되는 이벤트용. 상한에 걸리면 알림만 건너뛰고 도메인 행위
   * (응원 자체)는 그대로 둔다.
   *
   * @returns 알림을 만들었으면 true — 호출부는 이때만 푸시를 보낸다.
   */
  async createWithDailyCap(
    tx: Prisma.TransactionClient,
    userId: string,
    actorId: string | null,
    dedupeKey: { path: string; value: string },
    cap: number,
    input: NotificationInput,
  ): Promise<boolean> {
    if (actorId && actorId === userId) return false;
    const sentToday = await tx.notification.count({
      where: {
        userId,
        type: input.type,
        createdAt: { gte: kstDateOnly(new Date()) },
        data: { path: [dedupeKey.path], equals: dedupeKey.value },
      },
    });
    if (sentToday >= cap) return false;
    await this.create(tx, userId, input);
    return true;
  }

  /**
   * 같은 대상에 같은 종류 알림이 이미 있으면 건너뛴다.
   * 크루 글 응원처럼 **토글로 껐다 켰다 할 수 있는** 이벤트가 알림을
   * 반복 생성하는 걸 막는 용도.
   */
  async notifyOnce(
    userId: string,
    actorId: string | null,
    dedupeKey: { path: string; value: string },
    input: NotificationInput,
  ): Promise<void> {
    if (actorId && actorId === userId) return;
    const existing = await this.prisma.notification.findFirst({
      where: {
        userId,
        type: input.type,
        data: { path: [dedupeKey.path], equals: dedupeKey.value },
      },
      select: { id: true },
    });
    if (existing) return;
    await this.notify(userId, actorId, input);
  }

  /** GET /notifications — 최근 50건 + 안 읽은 수. */
  async list(userId: string) {
    const [items, unread] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.notification.count({ where: { userId, readAt: null } }),
    ]);
    return {
      unread,
      items: items.map((n) => ({
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data ?? null,
        read: n.readAt !== null,
        createdAt: n.createdAt,
      })),
    };
  }

  /** GET /notifications/unread-count — 탭 뱃지용 경량 엔드포인트. */
  async unreadCount(userId: string) {
    const unread = await this.prisma.notification.count({
      where: { userId, readAt: null },
    });
    return { unread };
  }

  /** POST /notifications/read — id 지정 시 그것만, 없으면 전체 읽음. */
  async markRead(userId: string, id?: string) {
    const now = new Date();
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null, ...(id ? { id } : {}) },
      data: { readAt: now },
    });
    return this.unreadCount(userId);
  }

  /** POST /devices — 푸시 토큰 등록(멱등). 같은 토큰이면 소유자를 옮긴다. */
  async registerDevice(userId: string, token: string, platform: string) {
    await this.prisma.deviceToken.upsert({
      where: { token },
      create: { userId, token, platform },
      // 재로그인·계정 전환 시 이전 유저에게 푸시가 가지 않도록 소유자 갱신.
      update: { userId, platform },
    });
    return { ok: true };
  }

  /** DELETE /devices/:token — 로그아웃 시 해제. */
  async unregisterDevice(userId: string, token: string) {
    await this.prisma.deviceToken.deleteMany({ where: { userId, token } });
    return { ok: true };
  }
}
