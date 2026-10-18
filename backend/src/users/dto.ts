import { IsEnum, IsOptional, IsString, Length, Matches } from 'class-validator';
import { Gender } from '@prisma/client';

export class UpdateMeDto {
  // @닉네임은 친구 검색·멘션에 쓰여 공백·기호를 막는다.
  @IsOptional()
  @IsString()
  @Matches(/^[a-zA-Z0-9_가-힣]{1,20}$/, {
    message: '닉네임은 한글·영문·숫자·밑줄 20자 이내예요',
  })
  nickname?: string;

  @IsOptional()
  @IsString()
  @Length(1, 20)
  displayName?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;
}
