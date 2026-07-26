import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { IsIn, IsOptional, IsString, Length } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { NotificationsService } from './notifications.service';

class MarkReadDto {
  /** 없으면 전체 읽음 처리. */
  @IsOptional()
  @IsString()
  id?: string;
}

class RegisterDeviceDto {
  @IsString()
  @Length(1, 4096)
  token!: string;

  @IsIn(['ios', 'android'])
  platform!: string;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('notifications')
  list(@CurrentUser() user: AuthUser) {
    return this.notifications.list(user.userId);
  }

  @Get('notifications/unread-count')
  unreadCount(@CurrentUser() user: AuthUser) {
    return this.notifications.unreadCount(user.userId);
  }

  @Post('notifications/read')
  markRead(@CurrentUser() user: AuthUser, @Body() dto: MarkReadDto) {
    return this.notifications.markRead(user.userId, dto.id);
  }

  @Post('devices')
  registerDevice(
    @CurrentUser() user: AuthUser,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.notifications.registerDevice(
      user.userId,
      dto.token,
      dto.platform,
    );
  }

  @Delete('devices/:token')
  unregisterDevice(
    @CurrentUser() user: AuthUser,
    @Param('token') token: string,
  ) {
    return this.notifications.unregisterDevice(user.userId, token);
  }
}
