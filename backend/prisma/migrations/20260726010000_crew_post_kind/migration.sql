-- 크루 피드 글 종류: 'post'(유저 글) | 'join'(새 크루원 합류 시스템 글)
ALTER TABLE "CrewPost" ADD COLUMN "kind" TEXT NOT NULL DEFAULT 'post';
