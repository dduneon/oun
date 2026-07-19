import { Module } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { GameModule } from '../game/game.module';
import { QuestsModule } from '../quests/quests.module';
import { AchievementsModule } from '../achievements/achievements.module';
import { WorkoutsService } from './workouts.service';
import { WorkoutsController } from './workouts.controller';

@Module({
  imports: [WalletModule, GameModule, QuestsModule, AchievementsModule],
  providers: [WorkoutsService],
  controllers: [WorkoutsController],
})
export class WorkoutsModule {}
