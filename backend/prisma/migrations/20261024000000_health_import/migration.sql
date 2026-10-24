CREATE TABLE `HealthWorkoutImport` (
  `id` VARCHAR(191) NOT NULL,
  `userId` VARCHAR(191) NOT NULL,
  `source` ENUM('manual', 'healthkit', 'health_connect') NOT NULL,
  `externalId` VARCHAR(191) NOT NULL,
  `workoutId` VARCHAR(191) NULL,
  UNIQUE INDEX `HealthWorkoutImport_workoutId_key` (`workoutId`),
  UNIQUE INDEX `HealthWorkoutImport_userId_source_externalId_key` (`userId`, `source`, `externalId`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `HealthWorkoutImport` ADD CONSTRAINT `HealthWorkoutImport_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `HealthWorkoutImport` ADD CONSTRAINT `HealthWorkoutImport_workoutId_fkey` FOREIGN KEY (`workoutId`) REFERENCES `WorkoutLog`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
