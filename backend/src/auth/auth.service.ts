import {
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Gender } from '@prisma/client';
import axios from 'axios';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  /** access/refresh 토큰 발급. */
  private issueTokens(user: { id: string; nickname: string }) {
    const accessTtl = this.config.get<string>('JWT_ACCESS_TTL') ?? '1h';
    const refreshTtl = this.config.get<string>('JWT_REFRESH_TTL') ?? '30d';
    const accessSecret = this.config.get<string>('JWT_ACCESS_SECRET');
    const refreshSecret = this.config.get<string>('JWT_REFRESH_SECRET');

    const accessToken = this.jwt.sign(
      { sub: user.id, nickname: user.nickname, typ: 'access' },
      { secret: accessSecret, expiresIn: accessTtl as unknown as number },
    );
    const refreshToken = this.jwt.sign(
      { sub: user.id, nickname: user.nickname, typ: 'refresh' },
      { secret: refreshSecret, expiresIn: refreshTtl as unknown as number },
    );
    return { accessToken, refreshToken };
  }

  private authResult(user: { id: string; nickname: string; gender: Gender }) {
    return {
      ...this.issueTokens(user),
      user: { id: user.id, nickname: user.nickname, gender: user.gender },
    };
  }

  /** 카카오 access token 검증 → 유저 find/create → 토큰 발급. */
  async kakaoLogin(accessToken: string) {
    let kakaoId: string;
    let nickname: string | undefined;
    try {
      const res = await axios.get('https://kapi.kakao.com/v2/user/me', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      kakaoId = String(res.data.id);
      nickname = res.data?.kakao_account?.profile?.nickname;
    } catch {
      throw new UnauthorizedException('카카오 인증에 실패했어요');
    }

    let user = await this.users.findByKakaoId(kakaoId);
    if (!user) {
      const unique = await this.users.ensureUniqueNickname(nickname ?? `oun_${kakaoId.slice(-6)}`);
      user = await this.users.provision({
        nickname: unique,
        displayName: nickname ?? unique,
        kakaoId,
      });
    }
    return this.authResult(user);
  }

  /** 개발용 로그인 스텁 — 자격증명 없이 닉네임만으로 유저 발급/재사용. 운영에서 차단. */
  async devLogin(nickname: string, gender?: Gender) {
    if (this.config.get<string>('NODE_ENV') === 'production') {
      throw new ForbiddenException('dev 로그인은 개발 환경에서만 사용할 수 있어요');
    }
    let user = await this.users.findByNickname(nickname);
    if (!user) {
      user = await this.users.provision({ nickname, gender });
    }
    return this.authResult(user);
  }

  /** refresh 토큰 검증 → 새 토큰 발급. */
  async refresh(refreshToken: string) {
    let payload: { sub: string; nickname: string; typ: string };
    try {
      payload = this.jwt.verify(refreshToken, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('세션이 만료됐어요. 다시 로그인해 주세요');
    }
    if (payload.typ !== 'refresh') {
      throw new UnauthorizedException();
    }
    return { ...this.issueTokens({ id: payload.sub, nickname: payload.nickname }) };
  }
}
