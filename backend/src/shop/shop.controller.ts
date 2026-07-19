import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { ShopService } from './shop.service';
import { CreateOrderDto, ItemQueryDto } from './dto';

@Controller()
@UseGuards(JwtAuthGuard)
export class ShopController {
  constructor(private readonly shop: ShopService) {}

  @Get('shop/items')
  items(@CurrentUser() user: AuthUser, @Query() query: ItemQueryDto) {
    return this.shop.items(user.userId, query.category);
  }

  @Post('shop/orders')
  order(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    return this.shop.order(user.userId, dto.itemKey);
  }

  @Get('inventory')
  inventory(@CurrentUser() user: AuthUser) {
    return this.shop.inventory(user.userId);
  }
}
