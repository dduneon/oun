import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { WalletModule } from './wallet/wallet.module';
import { WorkoutsModule } from './workouts/workouts.module';
import { CharacterModule } from './character/character.module';
import { QuestsModule } from './quests/quests.module';
import { ShopModule } from './shop/shop.module';
import { AchievementsModule } from './achievements/achievements.module';
import { GameModule } from './game/game.module';
import { SocialModule } from './social/social.module';
import { CrewsModule } from './crews/crews.module';
import { HealthController } from './health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    GameModule,
    AuthModule,
    UsersModule,
    WalletModule,
    WorkoutsModule,
    CharacterModule,
    QuestsModule,
    ShopModule,
    AchievementsModule,
    SocialModule,
    CrewsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
