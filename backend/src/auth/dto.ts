import { IsEnum, IsIn, IsOptional, IsString, Length } from 'class-validator';
import { Gender } from '@prisma/client';

export class KakaoLoginDto {
  // 앱이 카카오 SDK로 받은 access token. 서버가 카카오 API로 검증한다.
  @IsString()
  accessToken!: string;
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
