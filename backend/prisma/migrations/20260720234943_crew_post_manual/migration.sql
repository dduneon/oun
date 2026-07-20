-- 크루 피드 글: 운동 태그를 선택으로(자동 공유 제거). 같은 운동 중복 공유 방지.
ALTER TABLE "CrewPost" ALTER COLUMN "workoutLogId" DROP NOT NULL;
CREATE UNIQUE INDEX "CrewPost_crewId_workoutLogId_key" ON "CrewPost"("crewId", "workoutLogId");
