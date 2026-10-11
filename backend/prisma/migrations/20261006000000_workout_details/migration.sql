ALTER TABLE `WorkoutLog`
  ADD COLUMN `note` TEXT NULL,
  ADD COLUMN `effort` INTEGER NULL,
  ADD COLUMN `customSportName` VARCHAR(80) NULL;

CREATE TABLE `WorkoutExercise` (
  `id` VARCHAR(191) NOT NULL,
  `workoutId` VARCHAR(191) NOT NULL,
  `name` VARCHAR(80) NOT NULL,
  `position` INTEGER NOT NULL,
  INDEX `WorkoutExercise_workoutId_position_idx` (`workoutId`, `position`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `WorkoutSet` (
  `id` VARCHAR(191) NOT NULL,
  `exerciseId` VARCHAR(191) NOT NULL,
  `position` INTEGER NOT NULL,
  `weightKg` DOUBLE NOT NULL,
  `reps` INTEGER NOT NULL,
  INDEX `WorkoutSet_exerciseId_position_idx` (`exerciseId`, `position`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `WorkoutExercise` ADD CONSTRAINT `WorkoutExercise_workoutId_fkey`
  FOREIGN KEY (`workoutId`) REFERENCES `WorkoutLog`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `WorkoutSet` ADD CONSTRAINT `WorkoutSet_exerciseId_fkey`
  FOREIGN KEY (`exerciseId`) REFERENCES `WorkoutExercise`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
