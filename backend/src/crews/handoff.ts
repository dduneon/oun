import { Prisma } from '@prisma/client';

/**
 * 크루에서 한 명을 빼낸다(탈퇴·계정 삭제 공용).
 * - 마지막 방장이 나가면 가장 먼저 들어온 멤버에게 방장을 넘긴다.
 * - 남는 사람이 없으면 크루를 닫는다(글·댓글 등은 cascade).
 */
export async function releaseCrewMembership(
  tx: Prisma.TransactionClient,
  crewId: string,
  userId: string,
) {
  const me = await tx.crewMember.findUnique({ where: { crewId_userId: { crewId, userId } } });
  if (!me) return;
  await tx.crewMember.delete({ where: { id: me.id } });

  const remain = await tx.crewMember.findMany({ where: { crewId }, orderBy: { joinedAt: 'asc' } });
  if (remain.length === 0) {
    await tx.crew.delete({ where: { id: crewId } });
    return;
  }
  if (me.role === 'leader' && !remain.some((m) => m.role === 'leader')) {
    await tx.crewMember.update({ where: { id: remain[0].id }, data: { role: 'leader' } });
  }
}
