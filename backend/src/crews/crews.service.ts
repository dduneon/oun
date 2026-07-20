import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { AchievementsService } from '../achievements/achievements.service';
import { kstWeekStart } from '../common/time';
import { workoutSummary } from '../social/social.service';
import { crewLevelOf, crewLevelRewards } from './crew-level';

@Injectable()
export class CrewsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly achievements: AchievementsService,
  ) {}

  /** 멤버십 확인. 아니면 403. */
  private async membershipOf(crewId: string, userId: string) {
    const member = await this.prisma.crewMember.findUnique({
      where: { crewId_userId: { crewId, userId } },
    });
    if (!member) throw new ForbiddenException('크루 멤버가 아니에요');
    return member;
  }

  /** 이번 주(월~) 크루원별 검증 운동 횟수 맵. */
  private async weekCounts(memberIds: string[]) {
    const weekStart = kstWeekStart(new Date());
    const logs = await this.prisma.workoutLog.groupBy({
      by: ['userId'],
      where: {
        userId: { in: memberIds },
        verifyStatus: 'verified',
        performedAt: { gte: weekStart },
      },
      _count: { id: true },
    });
    return new Map(logs.map((l) => [l.userId, l._count.id]));
  }

  /** POST /crews — 생성 + 본인을 방장으로. 크루 데뷔 업적 판정. */
  async create(userId: string, name: string, weeklyGoal: number) {
    return this.prisma.$transaction(async (tx) => {
      const crew = await tx.crew.create({
        data: {
          name,
          weeklyGoal,
          members: { create: { userId, role: 'leader' } },
        },
      });
      await this.achievements.evaluate(tx, userId);
      return this.detailIn(tx, crew.id, userId);
    });
  }

  /** GET /crews — 내가 속한 크루 카드 목록. */
  async myCrews(userId: string) {
    const memberships = await this.prisma.crewMember.findMany({
      where: { userId },
      include: { crew: { include: { members: true, _count: { select: { posts: true } } } } },
      orderBy: { joinedAt: 'asc' },
    });

    const items = [];
    for (const m of memberships) {
      const crew = m.crew;
      const ids = crew.members.map((cm) => cm.userId);
      const counts = await this.weekCounts(ids);
      const weekDone = ids.reduce((s, id) => s + (counts.get(id) ?? 0), 0);
      items.push({
        id: crew.id,
        name: crew.name,
        weeklyGoal: crew.weeklyGoal,
        memberCount: ids.length,
        weekDone,
        target: crew.weeklyGoal * ids.length,
        level: crewLevelOf(crew._count.posts),
      });
    }
    return { items };
  }

  /** GET /crews/:id — 상세(멤버·주간 현황·레벨). */
  async detail(crewId: string, userId: string) {
    await this.membershipOf(crewId, userId);
    return this.detailIn(this.prisma, crewId, userId);
  }

  private async detailIn(
    client: Prisma.TransactionClient | PrismaService,
    crewId: string,
    userId: string,
  ) {
    const crew = await client.crew.findUnique({
      where: { id: crewId },
      include: {
        members: { include: { user: { include: { streak: true } } }, orderBy: { joinedAt: 'asc' } },
        _count: { select: { posts: true } },
      },
    });
    if (!crew) throw new NotFoundException('크루를 찾을 수 없어요');

    const ids = crew.members.map((m) => m.userId);
    const counts = await this.weekCounts(ids);
    const members = crew.members.map((m) => ({
      nickname: m.user.nickname,
      displayName: m.user.displayName,
      gender: m.user.gender,
      role: m.role,
      isMe: m.userId === userId,
      weekCount: counts.get(m.userId) ?? 0,
    }));
    const weekDone = members.reduce((s, m) => s + m.weekCount, 0);

    return {
      id: crew.id,
      name: crew.name,
      weeklyGoal: crew.weeklyGoal,
      members,
      weekDone,
      target: crew.weeklyGoal * members.length,
      level: crewLevelOf(crew._count.posts),
    };
  }

  /** POST /crews/:id/members — @nickname 직접 초대(링크 공유는 이후). */
  async invite(crewId: string, userId: string, nickname: string) {
    await this.membershipOf(crewId, userId);
    const target = await this.prisma.user.findUnique({ where: { nickname } });
    if (!target) throw new NotFoundException('해당 닉네임의 유저가 없어요');

    const dup = await this.prisma.crewMember.findUnique({
      where: { crewId_userId: { crewId, userId: target.id } },
    });
    if (dup) throw new ConflictException('이미 크루원이에요');

    return this.prisma.$transaction(async (tx) => {
      await tx.crewMember.create({ data: { crewId, userId: target.id } });
      await this.achievements.evaluate(tx, target.id); // 크루 데뷔
      return { nickname: target.nickname, displayName: target.displayName };
    });
  }

  /** DELETE /crews/:id/members/me — 크루 나가기. 마지막 멤버면 크루 삭제. */
  async leave(crewId: string, userId: string) {
    await this.membershipOf(crewId, userId);
    return this.prisma.$transaction(async (tx) => {
      await tx.crewMember.delete({ where: { crewId_userId: { crewId, userId } } });
      const remain = await tx.crewMember.count({ where: { crewId } });
      if (remain === 0) {
        await tx.crew.delete({ where: { id: crewId } });
      }
      return { left: true };
    });
  }

  /** POST /crews/:id/posts — 유저가 직접 글 작성. 운동 태그는 선택. */
  async createPost(
    crewId: string,
    userId: string,
    input: { workoutLogId?: string; message?: string },
  ) {
    await this.membershipOf(crewId, userId);
    const message = input.message?.trim() || null;
    const workoutLogId = input.workoutLogId || null;

    if (!workoutLogId && !message) {
      throw new BadRequestException('내용이나 태그할 운동을 넣어주세요');
    }

    if (workoutLogId) {
      const workout = await this.prisma.workoutLog.findUnique({ where: { id: workoutLogId } });
      if (!workout || workout.userId !== userId) {
        throw new BadRequestException('내 운동 기록만 태그할 수 있어요');
      }
      const dup = await this.prisma.crewPost.findUnique({
        where: { crewId_workoutLogId: { crewId, workoutLogId } },
      });
      if (dup) throw new ConflictException('이미 이 크루에 공유한 기록이에요');
    }

    const post = await this.prisma.crewPost.create({
      data: { crewId, userId, workoutLogId, message },
    });
    return { id: post.id };
  }

  /** GET /crews/:id/feed — 피드 글 + 댓글 + 응원. */
  async feed(crewId: string, userId: string) {
    await this.membershipOf(crewId, userId);
    const posts = await this.prisma.crewPost.findMany({
      where: { crewId },
      include: {
        user: true,
        comments: { include: { user: true }, orderBy: { createdAt: 'asc' } },
        cheers: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    // 게시글이 태그한 운동 상세를 한 번에 로드(태그 없는 글은 제외)
    const workoutIds = posts
      .map((p) => p.workoutLogId)
      .filter((id): id is string => id != null);
    const workouts = await this.prisma.workoutLog.findMany({ where: { id: { in: workoutIds } } });
    const workoutMap = new Map(workouts.map((w) => [w.id, w]));

    return {
      items: posts.map((p) => {
        const w = p.workoutLogId ? workoutMap.get(p.workoutLogId) : undefined;
        return {
          id: p.id,
          author: {
            nickname: p.user.nickname,
            displayName: p.user.displayName,
            gender: p.user.gender,
            isMe: p.userId === userId,
          },
          createdAt: p.createdAt.toISOString(),
          message: p.message,
          workout: w ? workoutSummary(w) : null,
          cheers: p.cheers.length,
          cheered: p.cheers.some((c) => c.userId === userId),
          comments: p.comments.map((c) => ({
            id: c.id,
            author: {
              nickname: c.user.nickname,
              displayName: c.user.displayName,
              isMe: c.userId === userId,
            },
            text: c.text,
            createdAt: c.createdAt.toISOString(),
          })),
        };
      }),
    };
  }

  /** POST /crews/posts/:postId/comments. */
  async comment(postId: string, userId: string, text: string) {
    const post = await this.prisma.crewPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('글을 찾을 수 없어요');
    await this.membershipOf(post.crewId, userId);

    const c = await this.prisma.crewComment.create({
      data: { postId, userId, text },
      include: { user: true },
    });
    return {
      id: c.id,
      author: { nickname: c.user.nickname, displayName: c.user.displayName, isMe: true },
      text: c.text,
      createdAt: c.createdAt.toISOString(),
    };
  }

  /** POST /crews/posts/:postId/cheer — 응원 토글. */
  async togglePostCheer(postId: string, userId: string) {
    const post = await this.prisma.crewPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('글을 찾을 수 없어요');
    await this.membershipOf(post.crewId, userId);

    const existing = await this.prisma.crewPostCheer.findUnique({
      where: { postId_userId: { postId, userId } },
    });
    if (existing) {
      await this.prisma.crewPostCheer.delete({ where: { id: existing.id } });
    } else {
      await this.prisma.crewPostCheer.create({ data: { postId, userId } });
    }
    const cheers = await this.prisma.crewPostCheer.count({ where: { postId } });
    return { cheered: !existing, cheers };
  }

  /** GET /crews/:id/rewards — 레벨 보상 목록(도달/수령 여부). */
  async rewards(crewId: string, userId: string) {
    await this.membershipOf(crewId, userId);
    const [postCount, claims] = await Promise.all([
      this.prisma.crewPost.count({ where: { crewId } }),
      this.prisma.crewRewardClaim.findMany({ where: { crewId, userId } }),
    ]);
    const level = crewLevelOf(postCount).level;
    const claimedSet = new Set(claims.map((c) => c.level));
    return {
      items: crewLevelRewards.map((r) => ({
        level: r.level,
        label: r.label,
        coins: r.coins,
        unlocked: level >= r.level,
        claimed: claimedSet.has(r.level),
      })),
    };
  }

  /** POST /crews/:id/rewards/:level/claim — 도달한 레벨 보상 수령(유저별 1회, 멱등). */
  async claimReward(crewId: string, userId: string, level: number) {
    await this.membershipOf(crewId, userId);
    const def = crewLevelRewards.find((r) => r.level === level);
    if (!def) throw new NotFoundException('없는 보상이에요');

    const postCount = await this.prisma.crewPost.count({ where: { crewId } });
    if (crewLevelOf(postCount).level < level) {
      throw new BadRequestException('아직 도달하지 못한 레벨이에요');
    }

    return this.prisma.$transaction(async (tx) => {
      const dup = await tx.crewRewardClaim.findUnique({
        where: { crewId_userId_level: { crewId, userId, level } },
      });
      if (dup) {
        const balance = await this.ledger.balanceOf(userId, tx);
        return { claimed: true, coins: 0, balance };
      }
      await tx.crewRewardClaim.create({ data: { crewId, userId, level } });
      let balance = await this.ledger.balanceOf(userId, tx);
      if (def.coins > 0) {
        const res = await this.ledger.append(tx, {
          userId,
          delta: def.coins,
          reason: 'quest_reward',
          refType: 'crew_reward',
          refId: `${crewId}:${level}`,
          idempotencyKey: `crewreward:${crewId}:${userId}:${level}`,
        });
        balance = res.balanceAfter;
      }
      return { claimed: true, coins: def.coins, balance };
    });
  }
}
