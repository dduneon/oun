import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { ReportsService } from './reports.service';

@Controller('reports')
@UseGuards(JwtAuthGuard)
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  /** GET /reports/monthly?month=YYYY-MM (없으면 이번 달) */
  @Get('monthly')
  monthly(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    return this.reports.monthly(user.userId, month);
  }
}
