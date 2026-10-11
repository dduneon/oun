import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  IsArray,
  ArrayMaxSize,
  ArrayMinSize,
  IsNumber,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { BodyPart, Sport, WorkoutSource } from '@prisma/client';

export class WorkoutSetDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(1000)
  weightKg!: number;

  @IsInt()
  @Min(1)
  @Max(1000)
  reps!: number;
}

export class WorkoutExerciseDto {
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => WorkoutSetDto)
  sets!: WorkoutSetDto[];
}

export class CreateWorkoutDto {
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  effort?: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  customSportName?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => WorkoutExerciseDto)
  exercises?: WorkoutExerciseDto[];
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
