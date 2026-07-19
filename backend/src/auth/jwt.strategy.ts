import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthUser } from '../common/current-user.decorator';

interface AccessPayload {
  sub: string;
  nickname: string;
  typ: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET') ?? 'dev-access-secret-change-me',
    });
  }

  validate(payload: AccessPayload): AuthUser {
    if (payload.typ !== 'access') {
      throw new UnauthorizedException();
    }
    return { userId: payload.sub, nickname: payload.nickname };
  }
}
