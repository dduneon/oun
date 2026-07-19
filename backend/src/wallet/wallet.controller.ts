import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { LedgerService } from './ledger.service';

@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(private readonly ledger: LedgerService) {}

  @Get()
  async wallet(@CurrentUser() user: AuthUser) {
    const balance = await this.ledger.balanceOf(user.userId);
    return { balance };
  }
}
