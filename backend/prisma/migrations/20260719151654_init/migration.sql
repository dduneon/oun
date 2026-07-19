-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('f', 'm');

-- CreateEnum
CREATE TYPE "LedgerReason" AS ENUM ('workout_reward', 'quest_reward', 'achievement', 'shop_purchase', 'rest_day', 'refund');

-- CreateEnum
CREATE TYPE "Sport" AS ENUM ('running', 'walking', 'weight', 'cycling', 'yoga', 'etc');

-- CreateEnum
CREATE TYPE "BodyPart" AS ENUM ('upper', 'lower', 'full', 'core');

-- CreateEnum
CREATE TYPE "WorkoutSource" AS ENUM ('manual', 'healthkit', 'health_connect');

-- CreateEnum
CREATE TYPE "VerifyStatus" AS ENUM ('pending', 'verified', 'rejected');

-- CreateEnum
CREATE TYPE "Mood" AS ENUM ('energetic', 'happy', 'neutral', 'hungry', 'sleepy');

-- CreateEnum
CREATE TYPE "QuestKind" AS ENUM ('daily', 'weekly', 'challenge');

-- CreateEnum
CREATE TYPE "QuestState" AS ENUM ('in_progress', 'claimable', 'claimed');

-- CreateEnum
CREATE TYPE "ItemCategory" AS ENUM ('clothing', 'hair', 'prop', 'furniture');

-- CreateEnum
CREATE TYPE "ItemRarity" AS ENUM ('common', 'rare', 'epic');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "kakaoId" TEXT,
    "nickname" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "gender" "Gender" NOT NULL DEFAULT 'f',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CurrencyLedger" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "delta" INTEGER NOT NULL,
    "balanceAfter" INTEGER NOT NULL,
    "reason" "LedgerReason" NOT NULL,
    "refType" TEXT,
    "refId" TEXT,
    "idempotencyKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CurrencyLedger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorkoutLog" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "sport" "Sport" NOT NULL,
    "durationSec" INTEGER NOT NULL,
    "distanceM" INTEGER,
    "steps" INTEGER,
    "bodyPart" "BodyPart",
    "sets" INTEGER,
    "calories" INTEGER,
    "photoRef" TEXT,
    "source" "WorkoutSource" NOT NULL DEFAULT 'manual',
    "verifyStatus" "VerifyStatus" NOT NULL DEFAULT 'pending',
    "rejectReason" TEXT,
    "performedAt" TIMESTAMP(3) NOT NULL,
    "verifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WorkoutLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CharacterStat" (
    "userId" TEXT NOT NULL,
    "endurance" INTEGER NOT NULL DEFAULT 0,
    "strength" INTEGER NOT NULL DEFAULT 0,
    "agility" INTEGER NOT NULL DEFAULT 0,
    "balance" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CharacterStat_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "CharacterMood" (
    "userId" TEXT NOT NULL,
    "mood" "Mood" NOT NULL DEFAULT 'neutral',
    "lastWorkoutAt" TIMESTAMP(3),
    "streakActive" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CharacterMood_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "Streak" (
    "userId" TEXT NOT NULL,
    "current" INTEGER NOT NULL DEFAULT 0,
    "longest" INTEGER NOT NULL DEFAULT 0,
    "lastActiveDate" TIMESTAMP(3),
    "protectedUntil" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Streak_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "StreakProtector" (
    "userId" TEXT NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "StreakProtector_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "RestDay" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "rewarded" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "RestDay_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QuestDef" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "kind" "QuestKind" NOT NULL,
    "title" TEXT NOT NULL,
    "sub" TEXT NOT NULL,
    "reward" INTEGER NOT NULL,
    "goal" INTEGER NOT NULL,
    "trigger" TEXT NOT NULL,
    "icon" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "QuestDef_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserQuest" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "questDefId" TEXT NOT NULL,
    "periodKey" TEXT NOT NULL,
    "progress" INTEGER NOT NULL DEFAULT 0,
    "state" "QuestState" NOT NULL DEFAULT 'in_progress',
    "claimedAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserQuest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Item" (
    "key" TEXT NOT NULL,
    "category" "ItemCategory" NOT NULL,
    "name" TEXT NOT NULL,
    "price" INTEGER NOT NULL,
    "rarity" "ItemRarity" NOT NULL DEFAULT 'common',
    "hasSpecialFx" BOOLEAN NOT NULL DEFAULT false,
    "addressableKey" TEXT,
    "colorHex" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "Item_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "Inventory" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "itemKey" TEXT NOT NULL,
    "acquiredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Inventory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Equipped" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "slot" TEXT NOT NULL,
    "itemKey" TEXT NOT NULL,

    CONSTRAINT "Equipped_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShopOrder" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "itemKey" TEXT NOT NULL,
    "price" INTEGER NOT NULL,
    "idempotencyKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ShopOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AchievementDef" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "condition" TEXT NOT NULL,
    "trigger" TEXT NOT NULL,
    "threshold" INTEGER NOT NULL DEFAULT 1,
    "icon" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "AchievementDef_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserAchievement" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "achievementDefId" TEXT NOT NULL,
    "earnedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserAchievement_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_kakaoId_key" ON "User"("kakaoId");

-- CreateIndex
CREATE UNIQUE INDEX "User_nickname_key" ON "User"("nickname");

-- CreateIndex
CREATE UNIQUE INDEX "CurrencyLedger_idempotencyKey_key" ON "CurrencyLedger"("idempotencyKey");

-- CreateIndex
CREATE INDEX "CurrencyLedger_userId_createdAt_idx" ON "CurrencyLedger"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "WorkoutLog_userId_performedAt_idx" ON "WorkoutLog"("userId", "performedAt");

-- CreateIndex
CREATE UNIQUE INDEX "RestDay_userId_date_key" ON "RestDay"("userId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "QuestDef_key_key" ON "QuestDef"("key");

-- CreateIndex
CREATE INDEX "UserQuest_userId_idx" ON "UserQuest"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "UserQuest_userId_questDefId_periodKey_key" ON "UserQuest"("userId", "questDefId", "periodKey");

-- CreateIndex
CREATE INDEX "Inventory_userId_idx" ON "Inventory"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Inventory_userId_itemKey_key" ON "Inventory"("userId", "itemKey");

-- CreateIndex
CREATE UNIQUE INDEX "Equipped_userId_slot_key" ON "Equipped"("userId", "slot");

-- CreateIndex
CREATE UNIQUE INDEX "ShopOrder_idempotencyKey_key" ON "ShopOrder"("idempotencyKey");

-- CreateIndex
CREATE UNIQUE INDEX "AchievementDef_key_key" ON "AchievementDef"("key");

-- CreateIndex
CREATE UNIQUE INDEX "UserAchievement_userId_achievementDefId_key" ON "UserAchievement"("userId", "achievementDefId");

-- AddForeignKey
ALTER TABLE "CurrencyLedger" ADD CONSTRAINT "CurrencyLedger_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WorkoutLog" ADD CONSTRAINT "WorkoutLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CharacterStat" ADD CONSTRAINT "CharacterStat_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CharacterMood" ADD CONSTRAINT "CharacterMood_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Streak" ADD CONSTRAINT "Streak_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StreakProtector" ADD CONSTRAINT "StreakProtector_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RestDay" ADD CONSTRAINT "RestDay_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserQuest" ADD CONSTRAINT "UserQuest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserQuest" ADD CONSTRAINT "UserQuest_questDefId_fkey" FOREIGN KEY ("questDefId") REFERENCES "QuestDef"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Inventory" ADD CONSTRAINT "Inventory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Inventory" ADD CONSTRAINT "Inventory_itemKey_fkey" FOREIGN KEY ("itemKey") REFERENCES "Item"("key") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipped" ADD CONSTRAINT "Equipped_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Equipped" ADD CONSTRAINT "Equipped_itemKey_fkey" FOREIGN KEY ("itemKey") REFERENCES "Item"("key") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShopOrder" ADD CONSTRAINT "ShopOrder_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ShopOrder" ADD CONSTRAINT "ShopOrder_itemKey_fkey" FOREIGN KEY ("itemKey") REFERENCES "Item"("key") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserAchievement" ADD CONSTRAINT "UserAchievement_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserAchievement" ADD CONSTRAINT "UserAchievement_achievementDefId_fkey" FOREIGN KEY ("achievementDefId") REFERENCES "AchievementDef"("id") ON DELETE CASCADE ON UPDATE CASCADE;
