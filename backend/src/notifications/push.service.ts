import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * FCM 푸시 전송.
 *
 * 자격증명(FIREBASE_SERVICE_ACCOUNT 또는 GOOGLE_APPLICATION_CREDENTIALS)이
 * 없으면 **조용히 no-op**으로 동작한다. 로컬·e2e·CI에서 알림 기능 전체가
 * 죽지 않게 하기 위한 것 — 인앱 알림함은 푸시와 무관하게 항상 남는다.
 *
 * firebase-admin은 선택적 의존성이라 require를 런타임에 시도한다.
 * (`npm i firebase-admin` 전에도 서버가 뜨도록)
 */
@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private messaging: {
    sendEachForMulticast(msg: unknown): Promise<{
      responses: { success: boolean; error?: { code?: string } }[];
    }>;
  } | null = null;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
    const hasAdc = !!process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!raw && !hasAdc) {
      this.logger.warn('FCM 자격증명 없음 — 푸시는 건너뜁니다(인앱 알림은 정상).');
      return;
    }

    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const admin = require('firebase-admin');
      if (!admin.apps.length) {
        admin.initializeApp({
          credential: raw
            ? admin.credential.cert(JSON.parse(raw))
            : admin.credential.applicationDefault(),
        });
      }
      this.messaging = admin.messaging();
      this.logger.log('FCM 초기화 완료');
    } catch (e) {
      this.logger.error(
        `FCM 초기화 실패 — 푸시는 건너뜁니다: ${(e as Error).message}`,
      );
      this.messaging = null;
    }
  }

  get enabled() {
    return this.messaging !== null;
  }

  /** 유저의 모든 기기로 전송. 실패해도 예외를 던지지 않는다(부가 기능). */
  async sendToUser(userId: string, payload: PushPayload): Promise<void> {
    if (!this.messaging) return;

    const devices = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    if (devices.length === 0) return;

    const tokens = devices.map((d) => d.token);
    try {
      const res = await this.messaging.sendEachForMulticast({
        tokens,
        notification: { title: payload.title, body: payload.body },
        data: payload.data ?? {},
        apns: { payload: { aps: { sound: 'default' } } },
        android: { priority: 'high' },
      });

      // 폐기된 토큰 정리 — 안 하면 죽은 기기에 계속 쏜다.
      const dead: string[] = [];
      res.responses.forEach((r, i) => {
        if (r.success) return;
        const code = r.error?.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          dead.push(tokens[i]);
        }
      });

      if (dead.length > 0) {
        await this.prisma.deviceToken.deleteMany({
          where: { token: { in: dead } },
        });
      }
    } catch (e) {
      this.logger.error(`푸시 전송 실패(userId=${userId}): ${(e as Error).message}`);
    }
  }
}
