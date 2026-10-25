import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Gender, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { statLevel } from '../game/leveling';
import { GameService } from '../game/game.service';
import { releaseCrewMembership } from '../crews/handoff';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly game: GameService,
  ) {}

  /** 신규 유저 생성 + 부속 상태 행(스탯/mood/스트릭/보호권) 초기화. */
  async provision(input: {
    nickname: string;
    displayName?: string;
    gender?: Gender;
    kakaoId?: string;
    appleId?: string;
    username?: string;
    passwordHash?: string;
    handleConfirmed?: boolean;
  }) {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          nickname: input.nickname,
          displayName: input.displayName ?? input.nickname,
          gender: input.gender ?? Gender.f,
          kakaoId: input.kakaoId,
          appleId: input.appleId,
          username: input.username,
          passwordHash: input.passwordHash,
          handleConfirmed: input.handleConfirmed ?? true,
          characterStat: { create: {} },
          characterMood: { create: {} },
          streak: { create: {} },
          streakProtector: { create: { count: 0 } },
        },
      });
      return user;
    });
  }

  async findByAppleId(appleId: string) {
    return this.prisma.user.findUnique({ where: { appleId } });
  }

  async findByKakaoId(kakaoId: string) {
    return this.prisma.user.findUnique({ where: { kakaoId } });
  }

  async findByNickname(nickname: string) {
    return this.prisma.user.findUnique({ where: { nickname } });
  }

  async findByUsername(username: string) {
    return this.prisma.user.findUnique({ where: { username } });
  }

  /** 소셜 가입용 임시 @아이디. 겹치면 뒤에 숫자를 붙인다(첫 화면에서 다시 정한다). */
  async ensureUniqueNickname(base: string): Promise<string> {
    // 아이디 규칙(영문 소문자·숫자·밑줄)에 맞게 다듬고, 뒤에 _n을 붙일 자리를 남긴다.
    const cleaned = base.toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 16);
    const clean = cleaned.length >= 3 ? cleaned : 'oun';
    let candidate = clean;
    let n = 1;
    while (await this.prisma.user.findUnique({ where: { nickname: candidate } })) {
      candidate = `${clean}_${n++}`;
    }
    return candidate;
  }

  /** GET /me — 마이/홈 상단에 필요한 프로필 집계. */
  async profile(userId: string) {
    // 빠진 날을 보호권으로 메우거나 끊긴 스트릭을 내린 뒤 보여 준다.
    await this.game.refreshStreak(userId);
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { characterStat: true, streak: true, streakProtector: true },
    });
    if (!user) throw new NotFoundException('유저를 찾을 수 없어요');

    const balance = await this.ledger.balanceOf(userId);
    const endurance = user.characterStat?.endurance ?? 0;
    // 홈 프로필의 대표 레벨은 지구력 기준(앱 '지구력 Lv.7').
    const level = statLevel(endurance);

    return {
      id: user.id,
      nickname: user.nickname,
      displayName: user.displayName,
      handleConfirmed: user.handleConfirmed,
      gender: user.gender,
      level,
      coin: balance,
      streak: {
        current: user.streak?.current ?? 0,
        longest: user.streak?.longest ?? 0,
      },
      streakProtectors: user.streakProtector?.count ?? 0,
    };
  }

  async update(userId: string, data: { nickname?: string; displayName?: string; gender?: Gender }) {
    const displayName = data.displayName?.trim();
    if (data.displayName !== undefined && !displayName) {
      throw new ConflictException('닉네임을 입력해 주세요');
    }
    // @아이디는 소셜 가입 직후 한 번만 정한다. 같은 값을 다시 보내는 건 허용.
    let handle: { nickname: string; handleConfirmed: true } | undefined;
    if (data.nickname !== undefined) {
      const me = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
      if (me.handleConfirmed && me.nickname !== data.nickname) {
        throw new ForbiddenException('아이디는 바꿀 수 없어요');
      }
      handle = { nickname: data.nickname, handleConfirmed: true };
    }
    try {
      await this.prisma.user.update({
        where: { id: userId },
        data: {
          ...(data.gender ? { gender: data.gender } : {}),
          ...(displayName ? { displayName } : {}),
          ...handle,
        },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('이미 사용 중인 아이디예요');
      }
      throw e;
    }
    return this.profile(userId);
  }

  /**
   * DELETE /me — 계정과 모든 기록을 지운다(되돌릴 수 없음).
   * 크루는 먼저 정리한다: 마지막 방장이면 방장을 넘기고, 혼자면 크루를 닫는다.
   * 나머지(기록·원장·친구·알림·기기 토큰 …)는 FK cascade로 함께 지워진다.
   */
  async remove(userId: string) {
    await this.prisma.$transaction(async (tx) => {
      const crews = await tx.crewMember.findMany({ where: { userId }, select: { crewId: true } });
      for (const { crewId } of crews) {
        await releaseCrewMembership(tx, crewId, userId);
      }
      await tx.user.delete({ where: { id: userId } });
    });
    return { deleted: true };
  }
}
