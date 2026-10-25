import {
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  Length,
  Matches,
} from 'class-validator';
import { Gender } from '@prisma/client';
import { Transform } from 'class-transformer';
import { HANDLE_MESSAGE, HANDLE_RE, normalizeHandle } from '../users/handle';

export class KakaoLoginDto {
  // 앱이 카카오 SDK로 받은 access token. 서버가 카카오 API로 검증한다.
  @IsString()
  accessToken!: string;
}

export class AppleLoginDto {
  // 앱이 Sign in with Apple로 받은 identity token(JWT). 서버가 애플 공개키로 검증한다.
  @IsString()
  identityToken!: string;

  // 애플은 이름을 첫 로그인 때만 준다 — 앱이 받은 이름을 같이 보낸다.
  @IsOptional()
  @IsString()
  @Length(0, 40)
  displayName?: string;
}

export class RegisterDto {
  // 아이디: 로그인 아이디이자 @아이디(친구 찾기). 가입 후 변경 불가.
  @Transform(({ value }) => normalizeHandle(value))
  @IsString()
  @Matches(HANDLE_RE, { message: HANDLE_MESSAGE })
  username!: string;

  @IsString()
  @Length(6, 72)
  password!: string;

  // 닉네임: 화면에 보이는 이름(자유).
  @IsString()
  @Length(1, 20)
  displayName!: string;

  @IsEnum(Gender)
  gender!: Gender;
}

export class LoginDto {
  @Transform(({ value }) => normalizeHandle(value))
  @IsString()
  username!: string;

  @IsString()
  password!: string;
}

export class DevLoginDto {
  @IsString()
  @Length(1, 20)
  nickname!: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  // 'signup': 신규 가입(닉네임 중복이면 거부), 'login': 기존 계정만 허용.
  // 생략하면 기존 동작(find-or-create) — e2e 등 하위호환용.
  @IsOptional()
  @IsIn(['signup', 'login'])
  mode?: 'signup' | 'login';
}

export class RefreshDto {
  @IsString()
  refreshToken!: string;
}
