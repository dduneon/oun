import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { IsOptional, IsString, Length } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { SocialService } from './social.service';

class AddFriendDto {
  @IsString()
  @Length(1, 20)
  nickname!: string;
}

class CheerDto {
  @IsOptional()
  @IsString()
  @Length(1, 8)
  emoji?: string;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class SocialController {
  constructor(private readonly social: SocialService) {}

  @Get('friends')
  friends(@CurrentUser() user: AuthUser) {
    return this.social.friends(user.userId);
  }

  @Post('friends')
  addFriend(@CurrentUser() user: AuthUser, @Body() dto: AddFriendDto) {
    return this.social.addFriend(user.userId, dto.nickname);
  }

  @Get('users/:nickname/home')
  friendHome(@Param('nickname') nickname: string) {
    return this.social.friendHome(nickname);
  }

  @Post('users/:nickname/cheer')
  cheer(
    @CurrentUser() user: AuthUser,
    @Param('nickname') nickname: string,
    @Body() dto: CheerDto,
  ) {
    return this.social.cheer(user.userId, nickname, dto.emoji);
  }
}
