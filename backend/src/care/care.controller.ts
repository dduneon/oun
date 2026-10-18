import { Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { CareService } from './care.service';

@Controller('care')
@UseGuards(JwtAuthGuard)
export class CareController {
  constructor(private readonly care: CareService) {}

  @Get()
  status(@CurrentUser() user: AuthUser) {
    return this.care.status(user.userId);
  }

  @Post('rest-day')
  declareRestDay(@CurrentUser() user: AuthUser) {
    return this.care.declareRestDay(user.userId);
  }
}
