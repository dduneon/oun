import { Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { QuestsService } from './quests.service';

@Controller('quests')
@UseGuards(JwtAuthGuard)
export class QuestsController {
  constructor(private readonly quests: QuestsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.quests.list(user.userId);
  }

  @Post(':key/claim')
  claim(@CurrentUser() user: AuthUser, @Param('key') key: string) {
    return this.quests.claim(user.userId, key);
  }
}
