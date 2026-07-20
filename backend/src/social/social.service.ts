import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { QuestsService } from '../quests/quests.service';
import { AchievementsService } from '../achievements/achievements.service';
import { statLevel } from '../game/leveling';
import { kstDateOnly, kstWeekStart } from '../common/time';

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
    return {
      items: rows.map((r) => {
        const f = r.friend;
        const latest = f.workouts[0] ?? null;
        return {
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

  /** POST /friends — @nickname으로 상호 친구 추가. */
  async addFriend(userId: string, nickname: string) {
    const target = await this.prisma.user.findUnique({ where: { nickname } });
    if (!target) throw new NotFoundException('해당 닉네임의 유저가 없어요');
    if (target.id === userId) throw new BadRequestException('나 자신은 추가할 수 없어요');

    const dup = await this.prisma.friendship.findUnique({
      where: { userId_friendId: { userId, friendId: target.id } },
    });
    if (dup) throw new ConflictException('이미 친구예요');

    await this.prisma.$transaction([
      this.prisma.friendship.create({ data: { userId, friendId: target.id } }),
      this.prisma.friendship.create({ data: { userId: target.id, friendId: userId } }),
    ]);
    return { nickname: target.nickname, displayName: target.displayName };
  }

  /** GET /users/:nickname/home — 친구 홈(주간 스트립 + 스탯 + 최근 활동). */
  async friendHome(nickname: string) {
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
    };
  }

  /** POST /users/:nickname/cheer — 응원 보내기(퀘스트·업적 반영). */
  async cheer(userId: string, nickname: string, emoji?: string) {
    const target = await this.prisma.user.findUnique({ where: { nickname } });
    if (!target) throw new NotFoundException('해당 닉네임의 유저가 없어요');
    if (target.id === userId) throw new BadRequestException('나 자신은 응원할 수 없어요');

    return this.prisma.$transaction(async (tx) => {
      await tx.cheer.create({
        data: { fromUserId: userId, toUserId: target.id, emoji: emoji ?? '❤️' },
      });
      await this.quests.onCheer(tx, userId);
      await this.achievements.evaluate(tx, userId);
      return { ok: true };
    });
  }
}
