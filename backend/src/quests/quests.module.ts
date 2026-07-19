import { Module } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { QuestsService } from './quests.service';
import { QuestsController } from './quests.controller';

@Module({
  imports: [WalletModule],
  providers: [QuestsService],
  controllers: [QuestsController],
  exports: [QuestsService],
})
export class QuestsModule {}
