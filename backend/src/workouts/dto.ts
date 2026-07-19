import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';
import { BodyPart, Sport, WorkoutSource } from '@prisma/client';

export class CreateWorkoutDto {
  @IsEnum(Sport)
  sport!: Sport;

  @IsInt()
  @Min(1)
  @Max(6 * 3600)
  durationSec!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  distanceM?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  steps?: number;

  @IsOptional()
  @IsEnum(BodyPart)
  bodyPart?: BodyPart;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(50)
  sets?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  calories?: number;

  // 운동 인증 사진 참조(S3 키 등). 없으면 미첨부.
  @IsOptional()
  @IsString()
  photoRef?: string;

  // 앱 목업 편의: 사진 첨부 여부만 넘길 때 사용.
  @IsOptional()
  @IsBoolean()
  hasPhoto?: boolean;

  @IsOptional()
  @IsEnum(WorkoutSource)
  source?: WorkoutSource;

  @IsOptional()
  @IsDateString()
  performedAt?: string;
}
