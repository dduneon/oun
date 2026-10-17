-- 성별 전용 아이템(헤어 등). NULL이면 남녀 공용.
ALTER TABLE `Item` ADD COLUMN `gender` ENUM('f', 'm') NULL;
