import { Module } from '@nestjs/common';
import { QuestsModule } from '../quests/quests.module';
import { AchievementsModule } from '../achievements/achievements.module';
import { SocialService } from './social.service';
import { SocialController } from './social.controller';

@Module({
  imports: [QuestsModule, AchievementsModule],
  providers: [SocialService],
  controllers: [SocialController],
  exports: [SocialService],
})
export class SocialModule {}
