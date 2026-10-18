-- 분류별 푸시 수신 설정
CREATE TABLE `NotificationSetting` (
    `userId` VARCHAR(191) NOT NULL,
    `friends` BOOLEAN NOT NULL DEFAULT true,
    `cheers` BOOLEAN NOT NULL DEFAULT true,
    `crew` BOOLEAN NOT NULL DEFAULT true,
    `care` BOOLEAN NOT NULL DEFAULT true,
    `updatedAt` DATETIME(3) NOT NULL,

    PRIMARY KEY (`userId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `NotificationSetting` ADD CONSTRAINT `NotificationSetting_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
