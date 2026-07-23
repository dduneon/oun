import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import {
  DevLoginDto,
  KakaoLoginDto,
  LoginDto,
  RefreshDto,
  RegisterDto,
} from './dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto.username, dto.password);
  }

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
