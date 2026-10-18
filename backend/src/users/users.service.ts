import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
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

  /** 닉네임 중복 시 뒤에 숫자를 붙여 유니크한 닉네임을 만든다. */
  async ensureUniqueNickname(base: string): Promise<string> {
    // @닉네임 규칙(한글·영문·숫자·밑줄)에 맞게 다듬는다 — 카카오·애플 이름엔 공백·기호가 섞인다.
    // 뒤에 _n을 붙일 자리를 남긴다.
    const clean = base.replace(/[^a-zA-Z0-9_가-힣]/g, '').slice(0, 16) || 'oun';
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
      throw new ConflictException('이름을 입력해 주세요');
    }
    try {
      await this.prisma.user.update({
        where: { id: userId },
        data: { ...data, ...(displayName ? { displayName } : {}) },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('이미 사용 중인 닉네임이에요');
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
