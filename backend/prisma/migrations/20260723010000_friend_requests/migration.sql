-- 친구 요청(요청 → 수락/거절)
CREATE TABLE "FriendRequest" (
    "id" TEXT NOT NULL,
    "fromUserId" TEXT NOT NULL,
    "toUserId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "FriendRequest_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "FriendRequest_fromUserId_toUserId_key" ON "FriendRequest"("fromUserId", "toUserId");
CREATE INDEX "FriendRequest_toUserId_idx" ON "FriendRequest"("toUserId");
ALTER TABLE "FriendRequest" ADD CONSTRAINT "FriendRequest_fromUserId_fkey" FOREIGN KEY ("fromUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FriendRequest" ADD CONSTRAINT "FriendRequest_toUserId_fkey" FOREIGN KEY ("toUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
