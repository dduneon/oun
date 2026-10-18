import { Module } from '@nestjs/common';
import { GameService } from './game.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  providers: [GameService],
  exports: [GameService],
})
export class GameModule {}
