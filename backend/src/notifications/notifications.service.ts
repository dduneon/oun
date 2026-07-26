import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
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
