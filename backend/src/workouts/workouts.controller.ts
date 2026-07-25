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

function currentMonth(): string {
  const kst = new Date(Date.now() + 9 * 3600 * 1000);
  return kst.toISOString().slice(0, 7);
}

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
  ) {
    return this.workouts.list(user.userId, from, to);
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

  @Get('calendar')
  calendar(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    return this.workouts.calendar(user.userId, month ?? currentMonth());
  }

  @Get('summary')
  summary(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    return this.workouts.summary(user.userId, month ?? currentMonth());
  }
}
