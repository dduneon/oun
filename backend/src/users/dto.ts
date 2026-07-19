import { IsEnum, IsOptional, IsString, Length } from 'class-validator';
import { Gender } from '@prisma/client';

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @Length(1, 20)
  nickname?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;
}
