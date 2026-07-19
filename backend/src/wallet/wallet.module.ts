import { Module } from '@nestjs/common';
import { LedgerService } from './ledger.service';
import { WalletController } from './wallet.controller';

@Module({
  providers: [LedgerService],
  controllers: [WalletController],
  exports: [LedgerService],
})
export class WalletModule {}
