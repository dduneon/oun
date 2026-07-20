import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { CrewsService } from './crews.service';

class CreateCrewDto {
  @IsString()
  @Length(1, 20)
  name!: string;

  @IsInt()
  @Min(1)
  @Max(14)
  weeklyGoal!: number;
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

@Controller('crews')
@UseGuards(JwtAuthGuard)
export class CrewsController {
  constructor(private readonly crews: CrewsService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCrewDto) {
    return this.crews.create(user.userId, dto.name, dto.weeklyGoal);
  }

  @Get()
  myCrews(@CurrentUser() user: AuthUser) {
    return this.crews.myCrews(user.userId);
  }

  @Get(':id')
  detail(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.crews.detail(id, user.userId);
  }

  @Post(':id/members')
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
