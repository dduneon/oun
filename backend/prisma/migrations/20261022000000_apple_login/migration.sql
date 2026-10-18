-- 애플 로그인 식별자
ALTER TABLE `User` ADD COLUMN `appleId` VARCHAR(191) NULL;
CREATE UNIQUE INDEX `User_appleId_key` ON `User`(`appleId`);
