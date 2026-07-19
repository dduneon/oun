import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { GameService } from '../game/game.service';
import { ShopService } from '../shop/shop.service';
import { EquipDto } from '../shop/dto';

@Controller('character')
@UseGuards(JwtAuthGuard)
export class CharacterController {
  constructor(
    private readonly game: GameService,
    private readonly shop: ShopService,
  ) {}

  @Get()
  character(@CurrentUser() user: AuthUser) {
    return this.game.character(user.userId);
  }

  @Get('mood')
  mood(@CurrentUser() user: AuthUser) {
    return this.game.mood(user.userId);
  }

  @Put('equip')
  equip(@CurrentUser() user: AuthUser, @Body() dto: EquipDto) {
    return this.shop.equip(user.userId, dto.itemKey, dto.slot);
  }
}
