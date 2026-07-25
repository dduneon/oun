import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  IsBoolean,
  IsOptional,
  IsString,
  Length,
} from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { CrewsService } from './crews.service';

class CreateCrewDto {
  @IsString()
  @Length(1, 20)
  name!: string;

  @IsOptional()
  @IsString()
  @Length(0, 200)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isPublic?: boolean;
}

class UpdateCrewDto {
  @IsOptional()
  @IsString()
  @Length(1, 20)
  name?: string;

  @IsOptional()
  @IsString()
  @Length(0, 200)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isPublic?: boolean;
}

class InviteDto {
  @IsString()
  @Length(1, 20)
  nickname!: string;
}

class CommentDto {
  @IsString()
  @Length(1, 300)
  text!: string;
}

class CreatePostDto {
  @IsOptional()
  @IsString()
  workoutLogId?: string;

  @IsOptional()
  @IsString()
  @Length(1, 300)
  message?: string;
}

class EditPostDto {
  @IsOptional()
  @IsString()
  @Length(0, 300)
  message?: string;

  // 빈 문자열이면 운동 태그 제거.
  @IsOptional()
  @IsString()
  workoutLogId?: string;
}

@Controller('crews')
@UseGuards(JwtAuthGuard)
export class CrewsController {
  constructor(private readonly crews: CrewsService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCrewDto) {
    return this.crews.create(user.userId, {
      name: dto.name,
      description: dto.description,
      isPublic: dto.isPublic ?? true,
    });
  }

  @Get()
  myCrews(@CurrentUser() user: AuthUser) {
    return this.crews.myCrews(user.userId);
  }

  // 리터럴 경로(discover·invitations)는 :id 보다 먼저 선언해야 파라미터로 안 잡힌다.
  @Get('discover')
  discover(@CurrentUser() user: AuthUser, @Query('q') q?: string) {
    return this.crews.discover(user.userId, q?.trim() || undefined);
  }

  @Get('invitations')
  invitations(@CurrentUser() user: AuthUser) {
    return this.crews.myInvitations(user.userId);
  }

  @Post('invitations/:invId/accept')
  acceptInvitation(
    @CurrentUser() user: AuthUser,
    @Param('invId') invId: string,
  ) {
    return this.crews.respondInvitation(user.userId, invId, true);
  }

  @Post('invitations/:invId/decline')
  declineInvitation(
    @CurrentUser() user: AuthUser,
    @Param('invId') invId: string,
  ) {
    return this.crews.respondInvitation(user.userId, invId, false);
  }

  @Get(':id')
  detail(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.crews.detail(id, user.userId);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateCrewDto,
  ) {
    return this.crews.update(id, user.userId, dto);
  }

  @Post(':id/invite')
  invite(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: InviteDto,
  ) {
    return this.crews.invite(id, user.userId, dto.nickname);
  }

  @Delete(':id/members/me')
  leave(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.crews.leave(id, user.userId);
  }

  // 가입 신청 (유저 → 크루)
  @Post(':id/join-request')
  requestJoin(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.crews.requestJoin(id, user.userId);
  }

  @Get(':id/join-requests')
  joinRequests(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.crews.listJoinRequests(id, user.userId);
  }

  @Post(':id/join-requests/:reqId/accept')
  acceptJoinRequest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('reqId') reqId: string,
  ) {
    return this.crews.respondJoinRequest(id, user.userId, reqId, true);
  }

  @Post(':id/join-requests/:reqId/reject')
  rejectJoinRequest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('reqId') reqId: string,
  ) {
    return this.crews.respondJoinRequest(id, user.userId, reqId, false);
  }

  @Get(':id/feed')
  feed(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.crews.feed(id, user.userId);
  }

  @Post(':id/posts')
  createPost(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreatePostDto,
  ) {
    return this.crews.createPost(id, user.userId, dto);
  }

  @Patch('posts/:postId')
  editPost(
    @CurrentUser() user: AuthUser,
    @Param('postId') postId: string,
    @Body() dto: EditPostDto,
  ) {
    return this.crews.editPost(postId, user.userId, {
      message: dto.message,
      workoutLogId: dto.workoutLogId,
    });
  }

  @Delete('posts/:postId')
  deletePost(@CurrentUser() user: AuthUser, @Param('postId') postId: string) {
    return this.crews.deletePost(postId, user.userId);
  }

  @Post('posts/:postId/comments')
  comment(
    @CurrentUser() user: AuthUser,
    @Param('postId') postId: string,
    @Body() dto: CommentDto,
  ) {
    return this.crews.comment(postId, user.userId, dto.text);
  }

  @Post('posts/:postId/cheer')
  cheerPost(@CurrentUser() user: AuthUser, @Param('postId') postId: string) {
    return this.crews.togglePostCheer(postId, user.userId);
  }

  @Get(':id/rewards')
  rewards(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.crews.rewards(id, user.userId);
  }

  @Post(':id/rewards/:level/claim')
  claimReward(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('level', ParseIntPipe) level: number,
  ) {
    return this.crews.claimReward(id, user.userId, level);
  }
}
