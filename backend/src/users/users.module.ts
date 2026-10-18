import { Module } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { GameModule } from '../game/game.module';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  imports: [WalletModule, GameModule],
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
