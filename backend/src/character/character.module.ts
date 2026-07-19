import { Module } from '@nestjs/common';
import { GameModule } from '../game/game.module';
import { ShopModule } from '../shop/shop.module';
import { CharacterController } from './character.controller';

@Module({
  imports: [GameModule, ShopModule],
  controllers: [CharacterController],
})
export class CharacterModule {}
