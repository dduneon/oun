import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { DevLoginDto, KakaoLoginDto, RefreshDto } from './dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('kakao')
  kakao(@Body() dto: KakaoLoginDto) {
    return this.auth.kakaoLogin(dto.accessToken);
  }

  @Post('dev')
  dev(@Body() dto: DevLoginDto) {
    return this.auth.devLogin(dto.nickname, dto.gender, dto.mode);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto.refreshToken);
  }
}
