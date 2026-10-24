import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { WorkoutsService } from './workouts.service';
import { CreateWorkoutDto } from './dto';
import { kstMonthKey } from '../common/time';

@Controller('workouts')
@UseGuards(JwtAuthGuard)
export class WorkoutsController {
  constructor(private readonly workouts: WorkoutsService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateWorkoutDto) {
    return this.workouts.create(user.userId, dto);
  }

  @Get()
  list(
    @CurrentUser() user: AuthUser,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('offset') offset?: string,
  ) {
    return this.workouts.list(user.userId, from, to, offset === undefined ? 0 : Number(offset));
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateWorkoutDto,
  ) {
    return this.workouts.update(user.userId, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.workouts.remove(user.userId, id);
  }

  @Get('health-imports')
  healthImports(@CurrentUser() user: AuthUser, @Query('after') after?: string) {
    return this.workouts.healthImports(user.userId, after);
  }

  @Get('calendar')
  calendar(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    return this.workouts.calendar(user.userId, month ?? kstMonthKey());
  }

  @Get('summary')
  summary(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    return this.workouts.summary(user.userId, month ?? kstMonthKey());
  }
}
