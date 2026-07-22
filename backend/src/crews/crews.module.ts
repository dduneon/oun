import { Module } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { AchievementsModule } from '../achievements/achievements.module';
import { StorageModule } from '../storage/storage.module';
import { CrewsService } from './crews.service';
import { CrewsController } from './crews.controller';

@Module({
  imports: [WalletModule, AchievementsModule, StorageModule],
  providers: [CrewsService],
  controllers: [CrewsController],
  exports: [CrewsService],
})
export class CrewsModule {}
