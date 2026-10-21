import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { LedgerService } from './ledger.service';
import { walletHistory } from './wallet-history';

@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(
    private readonly ledger: LedgerService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  async wallet(@CurrentUser() user: AuthUser) {
    const balance = await this.ledger.balanceOf(user.userId);
    return { balance };
  }

  /** GET /wallet/history — 최근 코인 변동 내역(최신순, 최대 100건). */
  @Get('history')
  async history(@CurrentUser() user: AuthUser) {
    const [balance, entries] = await Promise.all([
      this.ledger.balanceOf(user.userId),
      walletHistory(this.prisma, user.userId),
    ]);
    return { balance, entries };
  }
}
