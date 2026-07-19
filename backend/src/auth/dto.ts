import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
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
}

export class RefreshDto {
  @IsString()
  refreshToken!: string;
}
