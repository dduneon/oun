import { Module } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { GameModule } from '../game/game.module';
import { CareService } from './care.service';
import { CareController } from './care.controller';

@Module({
  imports: [WalletModule, GameModule],
  providers: [CareService],
  controllers: [CareController],
})
export class CareModule {}
