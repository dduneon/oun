import { Module } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { AchievementsModule } from '../achievements/achievements.module';
import { ShopService } from './shop.service';
import { ShopController } from './shop.controller';

@Module({
  imports: [WalletModule, AchievementsModule],
  providers: [ShopService],
  controllers: [ShopController],
  exports: [ShopService],
})
export class ShopModule {}
