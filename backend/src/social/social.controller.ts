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

  // 친구 요청 (요청 → 수락/거절)
  @Post('friends/requests')
  sendFriendRequest(
    @CurrentUser() user: AuthUser,
    @Body() dto: AddFriendDto,
  ) {
    return this.social.sendFriendRequest(user.userId, dto.nickname);
  }

  @Get('friends/requests')
  friendRequests(@CurrentUser() user: AuthUser) {
    return this.social.incomingFriendRequests(user.userId);
  }

  @Post('friends/requests/:id/accept')
  acceptFriendRequest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ) {
    return this.social.respondFriendRequest(user.userId, id, true);
  }

  @Post('friends/requests/:id/reject')
  rejectFriendRequest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ) {
    return this.social.respondFriendRequest(user.userId, id, false);
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

  // 내가 받은 응원 (보낸 쪽만 있던 기능의 수신자 측)
  @Get('cheers/received')
  receivedCheers(@CurrentUser() user: AuthUser) {
    return this.social.receivedCheers(user.userId);
  }

  @Post('cheers/received/seen')
  markCheersSeen(@CurrentUser() user: AuthUser) {
    return this.social.markCheersSeen(user.userId);
  }
}
