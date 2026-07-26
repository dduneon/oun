import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { QuestsService } from '../quests/quests.service';
import { AchievementsService } from '../achievements/achievements.service';
import { NotificationsService } from '../notifications/notifications.service';
import { statLevel } from '../game/leveling';
import { kstDateOnly, kstWeekStart } from '../common/time';

/** 한 사람에게 하루(KST)에 보낼 수 있는 응원 횟수. */
const CHEER_DAILY_LIMIT_PER_TARGET = 5;

/** 연타 방지 — 같은 사람에게 다시 보내기까지의 최소 간격(ms). */
const CHEER_COOLDOWN_MS = 5000;

/** WorkoutLog → 클라이언트 요약 공용 셰이프. */
export function workoutSummary(w: {
  id: string;
  sport: string;
  durationSec: number;
  distanceM: number | null;
  steps: number | null;
  bodyPart: string | null;
  sets: number | null;
  photoRef: string | null;
  performedAt: Date;
}) {
  return {
    id: w.id,
    sport: w.sport,
    durationSec: w.durationSec,
    distanceM: w.distanceM,
    steps: w.steps,
    bodyPart: w.bodyPart,
    sets: w.sets,
    hasPhoto: !!w.photoRef,
    performedAt: w.performedAt.toISOString(),
  };
}

@Injectable()
export class SocialService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly quests: QuestsService,
    private readonly achievements: AchievementsService,
    private readonly notifications: NotificationsService,
  ) {}

  /** GET /friends — 친구 목록 + 최근 활동 + 받은 반응 이모지. */
  async friends(userId: string) {
    const rows = await this.prisma.friendship.findMany({
      where: { userId },
      include: {
        friend: {
          include: {
            streak: true,
            workouts: {
              where: { verifyStatus: 'verified' },
              orderBy: { performedAt: 'desc' },
              take: 1,
            },
            cheersReceived: { orderBy: { createdAt: 'desc' }, take: 3 },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    const todayStart = kstDateOnly(new Date());
    const left = await this.cheersLeftToday(
      userId,
      rows.map((r) => r.friendId),
    );
    return {
      items: rows.map((r) => {
        const f = r.friend;
        const latest = f.workouts[0] ?? null;
        return {
          cheersLeftToday: left.get(f.id) ?? CHEER_DAILY_LIMIT_PER_TARGET,
          nickname: f.nickname,
          displayName: f.displayName,
          gender: f.gender,
          streakCurrent: f.streak?.current ?? 0,
          workedOutToday: latest ? latest.performedAt >= todayStart : false,
          latestWorkout: latest ? workoutSummary(latest) : null,
          reactions: [...new Set(f.cheersReceived.map((c) => c.emoji))],
        };
      }),
    };
  }

  /** 두 유저를 상호 친구로 만든다(멱등). 남아있는 서로의 요청은 정리한다. */
  private async makeFriends(userId: string, friendId: string) {
    await this.prisma.$transaction([
      this.prisma.friendship.upsert({
        where: { userId_friendId: { userId, friendId } },
        create: { userId, friendId },
        update: {},
      }),
      this.prisma.friendship.upsert({
        where: { userId_friendId: { userId: friendId, friendId: userId } },
        create: { userId: friendId, friendId: userId },
        update: {},
      }),
      this.prisma.friendRequest.updateMany({
        where: {
          status: 'pending',
          OR: [
            { fromUserId: userId, toUserId: friendId },
            { fromUserId: friendId, toUserId: userId },
          ],
        },
        data: { status: 'accepted' },
      }),
    ]);
  }

  /** POST /friends/requests — @nickname에게 친구 요청. 상대가 이미 내게
   *  요청했다면 바로 친구가 된다. */
  async sendFriendRequest(userId: string, nickname: string) {
    const target = await this.prisma.user.findUnique({ where: { nickname } });
    if (!target) throw new NotFoundException('해당 닉네임의 유저가 없어요');
    if (target.id === userId) throw new BadRequestException('나 자신은 추가할 수 없어요');

    const already = await this.prisma.friendship.findUnique({
      where: { userId_friendId: { userId, friendId: target.id } },
    });
    if (already) throw new ConflictException('이미 친구예요');

    // 상대가 내게 보낸 대기중 요청이 있으면 바로 수락 처리.
    const reverse = await this.prisma.friendRequest.findUnique({
      where: { fromUserId_toUserId: { fromUserId: target.id, toUserId: userId } },
    });
    if (reverse && reverse.status === 'pending') {
      await this.makeFriends(userId, target.id);
      return { status: 'accepted' as const, displayName: target.displayName };
    }

    await this.prisma.friendRequest.upsert({
      where: { fromUserId_toUserId: { fromUserId: userId, toUserId: target.id } },
      create: { fromUserId: userId, toUserId: target.id, status: 'pending' },
      update: { status: 'pending' }, // 예전에 거절됐어도 다시 요청 가능
    });

    // 알림이 없으면 상대가 요청을 영영 모른다(소셜 탭에 우연히 들어가야 발견).
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    await this.notifications.notify(target.id, userId, {
      type: 'friend_request',
      title: '친구 요청이 왔어요',
      body: `${me!.displayName}님이 친구가 되고 싶어해요`,
      data: { fromNickname: me!.nickname, fromDisplayName: me!.displayName },
    });

    return { status: 'requested' as const, displayName: target.displayName };
  }

  /** GET /friends/requests — 내가 받은 대기중 친구 요청. */
  async incomingFriendRequests(userId: string) {
    const reqs = await this.prisma.friendRequest.findMany({
      where: { toUserId: userId, status: 'pending' },
      include: { fromUser: true },
      orderBy: { createdAt: 'desc' },
    });
    return {
      items: reqs.map((r) => ({
        id: r.id,
        nickname: r.fromUser.nickname,
        displayName: r.fromUser.displayName,
        gender: r.fromUser.gender,
        createdAt: r.createdAt.toISOString(),
      })),
    };
  }

  /** POST /friends/requests/:id/(accept|reject) — 받은 요청 처리. */
  async respondFriendRequest(userId: string, reqId: string, accept: boolean) {
    const req = await this.prisma.friendRequest.findUnique({ where: { id: reqId } });
    if (!req || req.toUserId !== userId) {
      throw new NotFoundException('친구 요청을 찾을 수 없어요');
    }
    if (req.status !== 'pending') {
      throw new ConflictException('이미 처리된 요청이에요');
    }
    if (accept) {
      await this.makeFriends(userId, req.fromUserId);
      // 수락만 알린다 — 거절은 알리지 않는 게 이 앱의 정서에 맞다.
      const me = await this.prisma.user.findUnique({ where: { id: userId } });
      await this.notifications.notify(req.fromUserId, userId, {
        type: 'friend_accepted',
        title: '친구가 되었어요',
        body: `${me!.displayName}님이 친구 요청을 수락했어요`,
        data: { fromNickname: me!.nickname, fromDisplayName: me!.displayName },
      });
    } else {
      await this.prisma.friendRequest.update({
        where: { id: reqId },
        data: { status: 'rejected' },
      });
    }
    return { accepted: accept };
  }

  /**
   * 오늘(KST) 내가 이 사람들에게 응원을 몇 번 더 보낼 수 있는지.
   * 클라이언트가 세지 않도록 서버가 계산해 내려준다(제한의 근거는 서버).
   */
  private async cheersLeftToday(
    userId: string,
    targetIds: string[],
  ): Promise<Map<string, number>> {
    if (targetIds.length === 0) return new Map();
    const rows = await this.prisma.cheer.groupBy({
      by: ['toUserId'],
      where: {
        fromUserId: userId,
        toUserId: { in: targetIds },
        createdAt: { gte: kstDateOnly(new Date()) },
      },
      _count: { _all: true },
    });
    const sent = new Map(rows.map((r) => [r.toUserId, r._count._all]));
    return new Map(
      targetIds.map((id) => [
        id,
        Math.max(0, CHEER_DAILY_LIMIT_PER_TARGET - (sent.get(id) ?? 0)),
      ]),
    );
  }

  /** GET /users/:nickname/home — 친구 홈(주간 스트립 + 스탯 + 최근 활동). */
  async friendHome(nickname: string, viewerId: string) {
    const user = await this.prisma.user.findUnique({
      where: { nickname },
      include: { streak: true, characterStat: true },
    });
    if (!user) throw new NotFoundException('해당 닉네임의 유저가 없어요');

    const weekStart = kstWeekStart(new Date());
    const [weekLogs, recent] = await Promise.all([
      this.prisma.workoutLog.findMany({
        where: { userId: user.id, verifyStatus: 'verified', performedAt: { gte: weekStart } },
        select: { performedAt: true, durationSec: true },
      }),
      this.prisma.workoutLog.findMany({
        where: { userId: user.id, verifyStatus: 'verified' },
        orderBy: { performedAt: 'desc' },
        take: 5,
      }),
    ]);

    // 월~일 7칸 완료 여부
    const weekDone = Array<boolean>(7).fill(false);
    for (const w of weekLogs) {
      const idx = Math.floor(
        (kstDateOnly(w.performedAt).getTime() - weekStart.getTime()) / 86400000,
      );
      if (idx >= 0 && idx < 7) weekDone[idx] = true;
    }

    return {
      nickname: user.nickname,
      displayName: user.displayName,
      gender: user.gender,
      level: statLevel(user.characterStat?.endurance ?? 0),
      streakCurrent: user.streak?.current ?? 0,
      weekDone,
      weekCount: weekDone.filter(Boolean).length,
      weekMinutes: weekLogs.reduce((s, w) => s + Math.floor(w.durationSec / 60), 0),
      recent: recent.map(workoutSummary),
      cheersLeftToday:
        user.id === viewerId
          ? 0 // 나 자신은 응원할 수 없다
          : (await this.cheersLeftToday(viewerId, [user.id])).get(user.id) ?? 0,
      cheerDailyLimit: CHEER_DAILY_LIMIT_PER_TARGET,
    };
  }

  /** POST /users/:nickname/cheer — 응원 보내기(퀘스트·업적 + 받는 사람 알림). */
  async cheer(userId: string, nickname: string, emoji?: string) {
    const [target, sender] = await Promise.all([
      this.prisma.user.findUnique({ where: { nickname } }),
      this.prisma.user.findUnique({ where: { id: userId } }),
    ]);
    if (!target) throw new NotFoundException('해당 닉네임의 유저가 없어요');
    if (target.id === userId) throw new BadRequestException('나 자신은 응원할 수 없어요');

    // 보내는 행위 자체를 제한한다. 응원만 무한히 쌓이고 알림만 막으면
    // 하트 수와 실제 전달이 어긋나 앞뒤가 맞지 않는다.
    const [recentCheer, sentToday] = await Promise.all([
      this.prisma.cheer.findFirst({
        where: { fromUserId: userId, toUserId: target.id },
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true },
      }),
      this.prisma.cheer.count({
        where: {
          fromUserId: userId,
          toUserId: target.id,
          createdAt: { gte: kstDateOnly(new Date()) },
        },
      }),
    ]);

    if (
      recentCheer &&
      Date.now() - recentCheer.createdAt.getTime() < CHEER_COOLDOWN_MS
    ) {
      throw new BadRequestException('조금 뒤에 다시 응원할 수 있어요');
    }
    if (sentToday >= CHEER_DAILY_LIMIT_PER_TARGET) {
      throw new BadRequestException(
        `오늘 ${target.displayName}님에게 보낼 응원을 다 썼어요`,
      );
    }

    const mark = emoji ?? '❤️';
    const body = `${sender!.displayName}님이 응원을 보냈어요 ${mark}`;

    await this.prisma.$transaction(async (tx) => {
      await tx.cheer.create({
        data: { fromUserId: userId, toUserId: target.id, emoji: mark },
      });
      await this.quests.onCheer(tx, userId);
      await this.achievements.evaluate(tx, userId);

      // 인앱 알림은 트랜잭션 안에서 같이 커밋 — 응원만 남고 알림이 새는 일 방지.
      // 응원 횟수 자체가 위에서 제한되므로 알림에 따로 상한을 두지 않는다.
      await this.notifications.create(tx, target.id, {
        type: 'cheer',
        title: '응원이 도착했어요',
        body,
        data: {
          fromNickname: sender!.nickname,
          fromDisplayName: sender!.displayName,
          emoji: mark,
        },
      });
    });

    // 푸시는 커밋 후 fire-and-forget (실패해도 응원 자체는 성공).
    this.notifications.pushLater(target.id, {
      title: '응원이 도착했어요',
      body,
      data: { type: 'cheer', fromNickname: sender!.nickname },
    });

    return { ok: true };
  }

  /**
   * GET /cheers/received — 내가 받은 응원.
   *
   * `unseen`은 아직 확인하지 않은 응원 수로, 홈 캐릭터 반응 트리거로 쓰인다.
   * 조회만으로는 확인 처리하지 않는다(반응을 재생한 뒤 앱이 명시적으로 seen 호출).
   */
  async receivedCheers(userId: string) {
    const [rows, unseen] = await Promise.all([
      this.prisma.cheer.findMany({
        where: { toUserId: userId },
        orderBy: { createdAt: 'desc' },
        take: 50,
        include: {
          from: { select: { nickname: true, displayName: true, gender: true } },
        },
      }),
      this.prisma.cheer.count({ where: { toUserId: userId, seenAt: null } }),
    ]);

    return {
      unseen,
      total: rows.length,
      items: rows.map((c) => ({
        id: c.id,
        emoji: c.emoji,
        createdAt: c.createdAt,
        seen: c.seenAt !== null,
        fromNickname: c.from.nickname,
        fromDisplayName: c.from.displayName,
        fromGender: c.from.gender,
      })),
    };
  }

  /** POST /cheers/received/seen — 받은 응원 전체를 확인 처리. */
  async markCheersSeen(userId: string) {
    await this.prisma.cheer.updateMany({
      where: { toUserId: userId, seenAt: null },
      data: { seenAt: new Date() },
    });
    return { ok: true, unseen: 0 };
  }
}
