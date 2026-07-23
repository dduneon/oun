import {
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  Length,
  Matches,
} from 'class-validator';
import { Gender } from '@prisma/client';

export class KakaoLoginDto {
  // 앱이 카카오 SDK로 받은 access token. 서버가 카카오 API로 검증한다.
  @IsString()
  accessToken!: string;
}

export class RegisterDto {
  // 로그인 아이디: 영문/숫자/밑줄 4~20자.
  @IsString()
  @Matches(/^[a-zA-Z0-9_]{4,20}$/, {
    message: '아이디는 영문·숫자·밑줄 4~20자예요',
  })
  username!: string;

  @IsString()
  @Length(6, 72)
  password!: string;

  @IsString()
  @Length(1, 20)
  nickname!: string;

  @IsEnum(Gender)
  gender!: Gender;
}

export class LoginDto {
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
