-- AlterTable: 크루 소개/공개여부 추가, 주간목표 제거
ALTER TABLE "Crew" DROP COLUMN "weeklyGoal",
ADD COLUMN     "description" TEXT,
ADD COLUMN     "isPublic" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable: 가입 신청/초대
CREATE TABLE "CrewJoinRequest" (
    "id" TEXT NOT NULL,
    "crewId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "invitedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CrewJoinRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CrewJoinRequest_userId_idx" ON "CrewJoinRequest"("userId");
CREATE INDEX "CrewJoinRequest_crewId_idx" ON "CrewJoinRequest"("crewId");
CREATE UNIQUE INDEX "CrewJoinRequest_crewId_userId_type_key" ON "CrewJoinRequest"("crewId", "userId", "type");

-- AddForeignKey
ALTER TABLE "CrewJoinRequest" ADD CONSTRAINT "CrewJoinRequest_crewId_fkey" FOREIGN KEY ("crewId") REFERENCES "Crew"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CrewJoinRequest" ADD CONSTRAINT "CrewJoinRequest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
