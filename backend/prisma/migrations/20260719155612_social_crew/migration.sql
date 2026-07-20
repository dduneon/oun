-- CreateTable
CREATE TABLE "Friendship" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "friendId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Friendship_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Cheer" (
    "id" TEXT NOT NULL,
    "fromUserId" TEXT NOT NULL,
    "toUserId" TEXT NOT NULL,
    "emoji" TEXT NOT NULL DEFAULT '❤️',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Cheer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Crew" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "weeklyGoal" INTEGER NOT NULL DEFAULT 3,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Crew_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CrewMember" (
    "id" TEXT NOT NULL,
    "crewId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'member',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CrewMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CrewPost" (
    "id" TEXT NOT NULL,
    "crewId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "workoutLogId" TEXT NOT NULL,
    "message" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CrewPost_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CrewComment" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CrewComment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CrewPostCheer" (
    "id" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,

    CONSTRAINT "CrewPostCheer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CrewRewardClaim" (
    "id" TEXT NOT NULL,
    "crewId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "level" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CrewRewardClaim_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Friendship_userId_friendId_key" ON "Friendship"("userId", "friendId");

-- CreateIndex
CREATE INDEX "Cheer_toUserId_createdAt_idx" ON "Cheer"("toUserId", "createdAt");

-- CreateIndex
CREATE INDEX "Cheer_fromUserId_idx" ON "Cheer"("fromUserId");

-- CreateIndex
CREATE INDEX "CrewMember_userId_idx" ON "CrewMember"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "CrewMember_crewId_userId_key" ON "CrewMember"("crewId", "userId");

-- CreateIndex
CREATE INDEX "CrewPost_crewId_createdAt_idx" ON "CrewPost"("crewId", "createdAt");

-- CreateIndex
CREATE INDEX "CrewComment_postId_createdAt_idx" ON "CrewComment"("postId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "CrewPostCheer_postId_userId_key" ON "CrewPostCheer"("postId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "CrewRewardClaim_crewId_userId_level_key" ON "CrewRewardClaim"("crewId", "userId", "level");

-- AddForeignKey
ALTER TABLE "Friendship" ADD CONSTRAINT "Friendship_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Friendship" ADD CONSTRAINT "Friendship_friendId_fkey" FOREIGN KEY ("friendId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Cheer" ADD CONSTRAINT "Cheer_fromUserId_fkey" FOREIGN KEY ("fromUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Cheer" ADD CONSTRAINT "Cheer_toUserId_fkey" FOREIGN KEY ("toUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewMember" ADD CONSTRAINT "CrewMember_crewId_fkey" FOREIGN KEY ("crewId") REFERENCES "Crew"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewMember" ADD CONSTRAINT "CrewMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewPost" ADD CONSTRAINT "CrewPost_crewId_fkey" FOREIGN KEY ("crewId") REFERENCES "Crew"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewPost" ADD CONSTRAINT "CrewPost_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewComment" ADD CONSTRAINT "CrewComment_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CrewPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewComment" ADD CONSTRAINT "CrewComment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewPostCheer" ADD CONSTRAINT "CrewPostCheer_postId_fkey" FOREIGN KEY ("postId") REFERENCES "CrewPost"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewPostCheer" ADD CONSTRAINT "CrewPostCheer_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewRewardClaim" ADD CONSTRAINT "CrewRewardClaim_crewId_fkey" FOREIGN KEY ("crewId") REFERENCES "Crew"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CrewRewardClaim" ADD CONSTRAINT "CrewRewardClaim_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
