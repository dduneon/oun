import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Gender } from '@prisma/client';
import axios from 'axios';
import * as bcrypt from 'bcryptjs';
import { UsersService } from '../users/users.service';
import { AppleTokenVerifier } from './apple-token.verifier';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly apple: AppleTokenVerifier,
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

  /** isNew: 소셜 로그인으로 방금 만든 계정 — 앱이 캐릭터·닉네임 고르기를 보여 준다. */
  private authResult(user: { id: string; nickname: string; gender: Gender }, isNew = false) {
    return {
      ...this.issueTokens(user),
      user: { id: user.id, nickname: user.nickname, gender: user.gender },
      isNew,
    };
  }

  /** 회원가입: 아이디 + 비밀번호 + 닉네임 + 캐릭터. 아이디·닉네임 중복 거부. */
  async register(input: {
    username: string;
    password: string;
    nickname: string;
    gender: Gender;
  }) {
    if (await this.users.findByUsername(input.username)) {
      throw new ConflictException('이미 사용 중인 아이디예요');
    }
    if (await this.users.findByNickname(input.nickname)) {
      throw new ConflictException('이미 사용 중인 닉네임이에요');
    }
    const passwordHash = await bcrypt.hash(input.password, 10);
    const user = await this.users.provision({
      username: input.username,
      passwordHash,
      nickname: input.nickname,
      gender: input.gender,
    });
    return this.authResult(user);
  }

  /** 로그인: 아이디 + 비밀번호. */
  async login(username: string, password: string) {
    const user = await this.users.findByUsername(username);
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('아이디 또는 비밀번호가 올바르지 않아요');
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('아이디 또는 비밀번호가 올바르지 않아요');
    }
    return this.authResult(user);
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
    } catch (e) {
      // 401이라 예외 필터는 남기지 않는다 — 콘솔 설정 문제를 찾을 수 있게 카카오 응답을 남긴다.
      const err = e as { response?: { status?: number; data?: unknown }; message?: string };
      this.logger.warn(
        `카카오 토큰 검증 실패: ${err.response?.status ?? '-'} ${JSON.stringify(err.response?.data ?? err.message)}`,
      );
      throw new UnauthorizedException('카카오 인증에 실패했어요');
    }

    const existing = await this.users.findByKakaoId(kakaoId);
    if (existing) return this.authResult(existing);
    const unique = await this.users.ensureUniqueNickname(nickname || `oun_${kakaoId.slice(-6)}`);
    const user = await this.users.provision({
      nickname: unique,
      displayName: nickname?.trim().slice(0, 20) || unique,
      kakaoId,
    });
    return this.authResult(user, true);
  }

  /**
   * 애플 identity token 검증 → 유저 find/create → 토큰 발급.
   * 애플은 이름을 첫 로그인 때만 앱에 주므로, 앱이 받은 이름(displayName)을 같이 보낸다.
   */
  async appleLogin(identityToken: string, displayName?: string) {
    const { sub } = await this.apple.verify(identityToken);
    const existing = await this.users.findByAppleId(sub);
    if (existing) return this.authResult(existing);
    const name = displayName?.trim().slice(0, 20);
    const unique = await this.users.ensureUniqueNickname(name || `oun_${sub.replace(/\W/g, '').slice(-6)}`);
    const user = await this.users.provision({
      nickname: unique,
      displayName: name || unique,
      appleId: sub,
    });
    return this.authResult(user, true);
  }

  /**
   * 개발용 로그인/회원가입 스텁 — 자격증명 없이 닉네임만으로 유저 발급/재사용.
   * 운영에서 차단. (실 인증은 카카오 로그인)
   *
   * - mode 'signup': 신규 가입. 닉네임이 이미 있으면 거부하고, 없으면 캐릭터
   *   성별과 함께 생성한다.
   * - mode 'login': 기존 계정만 허용. 없으면 안내한다.
   * - mode 생략: 기존 동작(find-or-create). e2e 등 하위호환용.
   */
  async devLogin(
    nickname: string,
    gender?: Gender,
    mode?: 'signup' | 'login',
  ) {
    if (this.config.get<string>('NODE_ENV') === 'production') {
      throw new ForbiddenException('dev 로그인은 개발 환경에서만 사용할 수 있어요');
    }
    const existing = await this.users.findByNickname(nickname);

    if (mode === 'signup') {
      if (existing) {
        throw new ConflictException('이미 사용 중인 닉네임이에요');
      }
      const user = await this.users.provision({ nickname, gender });
      return this.authResult(user);
    }

    if (mode === 'login') {
      if (!existing) {
        throw new NotFoundException('존재하지 않는 계정이에요. 회원가입을 해주세요');
      }
      return this.authResult(existing);
    }

    // 하위호환: mode 없으면 find-or-create.
    const user = existing ?? (await this.users.provision({ nickname, gender }));
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
