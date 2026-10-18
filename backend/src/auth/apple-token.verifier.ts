import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { createPublicKey, JsonWebKey, KeyObject } from 'crypto';
import * as jwt from 'jsonwebtoken';

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';
const KEYS_TTL_MS = 60 * 60 * 1000;

interface AppleJwk extends JsonWebKey {
  kid: string;
}

/**
 * 애플 로그인 identity token(JWT) 검증. 애플 공개키(JWKS)로 서명을 확인하고
 * 발급자·대상(앱 번들 ID)·만료를 본다. 키는 한 시간 캐시하고, 모르는 kid가
 * 오면(애플이 키를 돌렸을 때) 한 번 다시 받는다.
 */
@Injectable()
export class AppleTokenVerifier {
  private keys: AppleJwk[] = [];
  private fetchedAt = 0;

  constructor(private readonly config: ConfigService) {}

  /** 검증된 애플 사용자 식별자(sub)와 이메일(있으면). */
  async verify(identityToken: string): Promise<{ sub: string; email?: string }> {
    const decoded = jwt.decode(identityToken, { complete: true });
    const kid = decoded?.header.kid;
    if (!kid) throw new UnauthorizedException('애플 인증에 실패했어요');

    const key = await this.keyFor(kid);
    const audience = (this.config.get<string>('APPLE_BUNDLE_ID') ?? 'com.dduneon.oun')
      .split(',')
      .map((s) => s.trim()) as [string, ...string[]];
    try {
      const payload = jwt.verify(identityToken, key, {
        algorithms: ['RS256'],
        issuer: APPLE_ISSUER,
        audience,
      }) as jwt.JwtPayload;
      if (!payload.sub) throw new Error('sub 없음');
      return { sub: payload.sub, email: payload.email as string | undefined };
    } catch {
      throw new UnauthorizedException('애플 인증에 실패했어요');
    }
  }

  private async keyFor(kid: string): Promise<KeyObject> {
    let jwk = this.keys.find((k) => k.kid === kid);
    if (!jwk || Date.now() - this.fetchedAt > KEYS_TTL_MS) {
      this.keys = await this.fetchKeys();
      this.fetchedAt = Date.now();
      jwk = this.keys.find((k) => k.kid === kid);
    }
    if (!jwk) throw new UnauthorizedException('애플 인증에 실패했어요');
    return createPublicKey({ key: jwk, format: 'jwk' });
  }

  /** 애플 공개키 목록. 테스트에서 바꿔 끼운다. */
  async fetchKeys(): Promise<AppleJwk[]> {
    try {
      const res = await axios.get<{ keys: AppleJwk[] }>(APPLE_KEYS_URL, { timeout: 5000 });
      return res.data.keys;
    } catch {
      throw new UnauthorizedException('애플 인증 서버에 연결하지 못했어요');
    }
  }
}
