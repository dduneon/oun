import { Injectable, NotFoundException } from '@nestjs/common';
import { Gender, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from '../wallet/ledger.service';
import { statLevel } from '../game/leveling';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  /** 신규 유저 생성 + 부속 상태 행(스탯/mood/스트릭/보호권) 초기화. */
  async provision(input: {
    nickname: string;
    displayName?: string;
    gender?: Gender;
    kakaoId?: string;
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
    const clean = base.trim().slice(0, 20) || 'oun';
    let candidate = clean;
    let n = 1;
    while (await this.prisma.user.findUnique({ where: { nickname: candidate } })) {
      candidate = `${clean}_${n++}`;
    }
    return candidate;
  }

  /** GET /me — 마이/홈 상단에 필요한 프로필 집계. */
  async profile(userId: string) {
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

  async update(userId: string, data: { nickname?: string; gender?: Gender }) {
    try {
      await this.prisma.user.update({ where: { id: userId }, data });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new NotFoundException('이미 사용 중인 닉네임이에요');
      }
      throw e;
    }
    return this.profile(userId);
  }
}
