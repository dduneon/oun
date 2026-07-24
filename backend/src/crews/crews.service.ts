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
import { workoutSummary } from '../social/social.service';
import { StorageService } from '../storage/storage.service';
import { crewLevelOf, crewLevelRewards } from './crew-level';

@Injectable()
export class CrewsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly achievements: AchievementsService,
    private readonly storage: StorageService,
  ) {}

  /** 멤버십 확인. 아니면 403. */
  private async membershipOf(crewId: string, userId: string) {
    const member = await this.prisma.crewMember.findUnique({
      where: { crewId_userId: { crewId, userId } },
    });
    if (!member) throw new ForbiddenException('크루 멤버가 아니에요');
    return member;
  }

  /** 방장 확인. 방장이 아니면 403. (가입 신청 승인·초대·설정 변경 권한) */
  private async leaderOf(crewId: string, userId: string) {
    const member = await this.membershipOf(crewId, userId);
    if (member.role !== 'leader') {
      throw new ForbiddenException('방장만 할 수 있어요');
    }
    return member;
  }

  /** 크루에 새 멤버를 넣고, 관련 대기중 신청/초대를 정리한다(멱등). */
  private async admit(tx: Prisma.TransactionClient, crewId: string, userId: string) {
    await tx.crewMember.upsert({
      where: { crewId_userId: { crewId, userId } },
      create: { crewId, userId },
      update: {},
    });
    // 같은 크루에 남아있는 이 유저의 대기중 신청/초대는 모두 처리 완료로.
    await tx.crewJoinRequest.updateMany({
      where: { crewId, userId, status: 'pending' },
      data: { status: 'accepted' },
    });
    await this.achievements.evaluate(tx, userId); // 크루 데뷔 업적
  }

  /** POST /crews — 생성 + 본인을 방장으로. 크루 데뷔 업적 판정. */
  async create(
    userId: string,
    input: { name: string; description?: string; isPublic: boolean },
  ) {
    return this.prisma.$transaction(async (tx) => {
      const crew = await tx.crew.create({
        data: {
          name: input.name,
          description: input.description?.trim() || null,
          isPublic: input.isPublic,
          members: { create: { userId, role: 'leader' } },
        },
      });
      await this.achievements.evaluate(tx, userId);
      return this.detailIn(tx, crew.id, userId);
    });
  }

  /** PATCH /crews/:id — 크루 설정(이름·소개·공개여부) 변경. 방장만. */
  async update(
    crewId: string,
    userId: string,
    input: { name?: string; description?: string; isPublic?: boolean },
  ) {
    await this.leaderOf(crewId, userId);
    await this.prisma.crew.update({
      where: { id: crewId },
      data: {
        name: input.name,
        description:
          input.description === undefined
            ? undefined
            : input.description.trim() || null,
        isPublic: input.isPublic,
      },
    });
    return this.detailIn(this.prisma, crewId, userId);
  }

  /** GET /crews — 내가 속한 크루 카드 목록. */
  async myCrews(userId: string) {
    const memberships = await this.prisma.crewMember.findMany({
      where: { userId },
      include: { crew: { include: { _count: { select: { members: true, posts: true } } } } },
      orderBy: { joinedAt: 'asc' },
    });

    const items = memberships.map((m) => ({
      id: m.crew.id,
      name: m.crew.name,
      description: m.crew.description,
      isPublic: m.crew.isPublic,
      memberCount: m.crew._count.members,
      level: crewLevelOf(m.crew._count.posts),
    }));
    return { items };
  }

  /** GET /crews/:id — 상세(멤버·레벨·설정). */
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
        members: { include: { user: true }, orderBy: { joinedAt: 'asc' } },
        _count: { select: { posts: true } },
      },
    });
    if (!crew) throw new NotFoundException('크루를 찾을 수 없어요');

    const me = crew.members.find((m) => m.userId === userId);
    const isLeader = me?.role === 'leader';
    const members = crew.members.map((m) => ({
      nickname: m.user.nickname,
      displayName: m.user.displayName,
      gender: m.user.gender,
      role: m.role,
      isMe: m.userId === userId,
    }));

    // 방장이면 대기중 가입 신청 수를 함께 내려 배지로 노출.
    const pendingRequestCount = isLeader
      ? await client.crewJoinRequest.count({
          where: { crewId, type: 'request', status: 'pending' },
        })
      : 0;

    return {
      id: crew.id,
      name: crew.name,
      description: crew.description,
      isPublic: crew.isPublic,
      isLeader,
      pendingRequestCount,
      members,
      level: crewLevelOf(crew._count.posts),
    };
  }

  // ── 탐방 / 가입 신청 (유저 → 크루) ────────────────────────

  /** GET /crews/discover — 내가 속하지 않은 공개 크루 목록(이름 검색). */
  async discover(userId: string, q?: string) {
    const myCrewIds = (
      await this.prisma.crewMember.findMany({
        where: { userId },
        select: { crewId: true },
      })
    ).map((m) => m.crewId);

    const crews = await this.prisma.crew.findMany({
      where: {
        isPublic: true,
        id: { notIn: myCrewIds },
        ...(q ? { name: { contains: q, mode: 'insensitive' } } : {}),
      },
      include: { _count: { select: { members: true, posts: true } } },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    // 내가 이미 신청한 크루 표시.
    const requested = new Set(
      (
        await this.prisma.crewJoinRequest.findMany({
          where: { userId, type: 'request', status: 'pending', crewId: { in: crews.map((c) => c.id) } },
          select: { crewId: true },
        })
      ).map((r) => r.crewId),
    );

    return {
      items: crews.map((c) => ({
        id: c.id,
        name: c.name,
        description: c.description,
        memberCount: c._count.members,
        level: crewLevelOf(c._count.posts),
        requested: requested.has(c.id),
      })),
    };
  }

  /** POST /crews/:id/join-request — 공개 크루에 가입 신청. */
  async requestJoin(crewId: string, userId: string) {
    const crew = await this.prisma.crew.findUnique({ where: { id: crewId } });
    if (!crew) throw new NotFoundException('크루를 찾을 수 없어요');
    if (!crew.isPublic) throw new ForbiddenException('비공개 크루예요');

    const member = await this.prisma.crewMember.findUnique({
      where: { crewId_userId: { crewId, userId } },
    });
    if (member) throw new ConflictException('이미 크루원이에요');

    await this.prisma.crewJoinRequest.upsert({
      where: { crewId_userId_type: { crewId, userId, type: 'request' } },
      create: { crewId, userId, type: 'request', status: 'pending' },
      update: { status: 'pending' }, // 이전에 거절됐어도 다시 신청 가능
    });
    return { requested: true };
  }

  /** GET /crews/:id/join-requests — 방장이 보는 대기중 가입 신청. */
  async listJoinRequests(crewId: string, userId: string) {
    await this.leaderOf(crewId, userId);
    const reqs = await this.prisma.crewJoinRequest.findMany({
      where: { crewId, type: 'request', status: 'pending' },
      include: { user: true },
      orderBy: { createdAt: 'asc' },
    });
    return {
      items: reqs.map((r) => ({
        id: r.id,
        nickname: r.user.nickname,
        displayName: r.user.displayName,
        gender: r.user.gender,
        createdAt: r.createdAt.toISOString(),
      })),
    };
  }

  /** POST /crews/:id/join-requests/:reqId/(accept|reject) — 방장 처리. */
  async respondJoinRequest(
    crewId: string,
    userId: string,
    reqId: string,
    accept: boolean,
  ) {
    await this.leaderOf(crewId, userId);
    const req = await this.prisma.crewJoinRequest.findUnique({ where: { id: reqId } });
    if (!req || req.crewId !== crewId || req.type !== 'request') {
      throw new NotFoundException('가입 신청을 찾을 수 없어요');
    }
    if (req.status !== 'pending') {
      throw new ConflictException('이미 처리된 신청이에요');
    }

    return this.prisma.$transaction(async (tx) => {
      if (accept) {
        await this.admit(tx, crewId, req.userId);
      } else {
        await tx.crewJoinRequest.update({
          where: { id: reqId },
          data: { status: 'rejected' },
        });
      }
      return { accepted: accept };
    });
  }

  // ── 초대 (크루 → 유저) ────────────────────────────────────

  /** POST /crews/:id/invite — @nickname 초대(대기중 초대 생성, 방장만). */
  async invite(crewId: string, userId: string, nickname: string) {
    await this.leaderOf(crewId, userId);
    const target = await this.prisma.user.findUnique({ where: { nickname } });
    if (!target) throw new NotFoundException('해당 닉네임의 유저가 없어요');

    const dup = await this.prisma.crewMember.findUnique({
      where: { crewId_userId: { crewId, userId: target.id } },
    });
    if (dup) throw new ConflictException('이미 크루원이에요');

    await this.prisma.crewJoinRequest.upsert({
      where: { crewId_userId_type: { crewId, userId: target.id, type: 'invite' } },
      create: {
        crewId,
        userId: target.id,
        type: 'invite',
        status: 'pending',
        invitedBy: userId,
      },
      update: { status: 'pending', invitedBy: userId },
    });
    return { nickname: target.nickname, displayName: target.displayName };
  }

  /** GET /crews/invitations — 내가 받은 대기중 초대 목록. */
  async myInvitations(userId: string) {
    const invites = await this.prisma.crewJoinRequest.findMany({
      where: { userId, type: 'invite', status: 'pending' },
      include: { crew: { include: { _count: { select: { members: true } } } } },
      orderBy: { createdAt: 'desc' },
    });

    // 초대한 방장 이름.
    const inviterIds = invites
      .map((i) => i.invitedBy)
      .filter((id): id is string => id != null);
    const inviters = await this.prisma.user.findMany({
      where: { id: { in: inviterIds } },
    });
    const inviterMap = new Map(inviters.map((u) => [u.id, u.displayName]));

    return {
      items: invites.map((i) => ({
        id: i.id,
        crewId: i.crewId,
        crewName: i.crew.name,
        crewDescription: i.crew.description,
        memberCount: i.crew._count.members,
        invitedByName: i.invitedBy ? inviterMap.get(i.invitedBy) ?? null : null,
        createdAt: i.createdAt.toISOString(),
      })),
    };
  }

  /** POST /crews/invitations/:invId/(accept|decline) — 초대받은 사람 처리. */
  async respondInvitation(userId: string, invId: string, accept: boolean) {
    const inv = await this.prisma.crewJoinRequest.findUnique({ where: { id: invId } });
    if (!inv || inv.userId !== userId || inv.type !== 'invite') {
      throw new NotFoundException('초대를 찾을 수 없어요');
    }
    if (inv.status !== 'pending') {
      throw new ConflictException('이미 처리된 초대예요');
    }

    return this.prisma.$transaction(async (tx) => {
      if (accept) {
        await this.admit(tx, inv.crewId, userId);
      } else {
        await tx.crewJoinRequest.update({
          where: { id: invId },
          data: { status: 'rejected' },
        });
      }
      return { accepted: accept };
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

  /** PATCH /crews/posts/:postId — 본인 글의 한마디 수정. */
  async editPost(postId: string, userId: string, message: string) {
    const post = await this.prisma.crewPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('글을 찾을 수 없어요');
    if (post.userId !== userId) throw new ForbiddenException('내 글만 수정할 수 있어요');

    const trimmed = message.trim();
    if (!trimmed && !post.workoutLogId) {
      throw new BadRequestException('내용을 입력해 주세요');
    }
    await this.prisma.crewPost.update({
      where: { id: postId },
      data: { message: trimmed || null },
    });
    return { id: postId };
  }

  /** DELETE /crews/posts/:postId — 본인 글 삭제(댓글·응원 함께 삭제). */
  async deletePost(postId: string, userId: string) {
    const post = await this.prisma.crewPost.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('글을 찾을 수 없어요');
    if (post.userId !== userId) throw new ForbiddenException('내 글만 삭제할 수 있어요');

    await this.prisma.crewPost.delete({ where: { id: postId } });
    return { deleted: true };
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
          workout: w
              ? { ...workoutSummary(w), photoUrl: this.storage.publicUrlFor(w.photoRef) }
              : null,
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
