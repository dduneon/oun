import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsIn, IsOptional, IsString } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { StorageService } from './storage.service';

class PresignPhotoDto {
  @IsOptional()
  @IsString()
  @IsIn(['image/jpeg', 'image/png'])
  contentType?: string;
}

@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(private readonly storage: StorageService) {}

  /** 운동 사진 업로드용 presigned URL 발급. 앱은 uploadUrl로 PUT 후 key를 워크아웃에 첨부한다. */
  @Post('workout-photo')
  workoutPhoto(@CurrentUser() user: AuthUser, @Body() dto: PresignPhotoDto) {
    return this.storage.presignWorkoutPhoto(
      user.userId,
      dto.contentType ?? 'image/jpeg',
    );
  }
}
