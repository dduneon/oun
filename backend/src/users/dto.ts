import { IsEnum, IsOptional, IsString, Length, Matches } from 'class-validator';
import { Gender } from '@prisma/client';
import { Transform } from 'class-transformer';
import { HANDLE_MESSAGE, HANDLE_RE, normalizeHandle } from './handle';

export class UpdateMeDto {
  // @아이디. 소셜 가입 직후 첫 화면에서만 정할 수 있다(이후 403).
  @IsOptional()
  @Transform(({ value }) => normalizeHandle(value))
  @IsString()
  @Matches(HANDLE_RE, { message: HANDLE_MESSAGE })
  nickname?: string;

  @IsOptional()
  @IsString()
  @Length(1, 20)
  displayName?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;
}
