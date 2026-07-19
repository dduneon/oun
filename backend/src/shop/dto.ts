import { IsEnum, IsOptional, IsString } from 'class-validator';
import { ItemCategory } from '@prisma/client';

export class CreateOrderDto {
  @IsString()
  itemKey!: string;
}

export class EquipDto {
  @IsString()
  itemKey!: string;

  // 미지정 시 아이템 카테고리로 슬롯을 정한다.
  @IsOptional()
  @IsString()
  slot?: string;
}

export class ItemQueryDto {
  @IsOptional()
  @IsEnum(ItemCategory)
  category?: ItemCategory;
}
