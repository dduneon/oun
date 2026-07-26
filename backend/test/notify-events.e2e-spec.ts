import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/**
 * 알림이 생기는 이벤트 전반 e2e: 친구 요청/수락, 크루 가입 신청·결과,
 * 초대, 댓글, 글 응원. (응원 알림은 notifications.e2e-spec 담당)
 * 실행 전 docker compose up + migrate 필요.
 */
describe('오운 알림 트리거 (e2e)', () => {
  let app: INestApplication;
  let leader: string; // 크루 방장 = 글쓴이
  let member: string; // 신청·댓글·응원 하는 쪽
  const leaderNick = `nl_${Date.now().toString().slice(-9)}`;
  const memberNick = `nm_${Date.now().toString().slice(-9)}`;
  let crewId: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    const a = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: leaderNick });
    leader = a.body.accessToken;
    const b = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: memberNick });
    member = b.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  const asLeader = () => ({ Authorization: `Bearer ${leader}` });
  const asMember = () => ({ Authorization: `Bearer ${member}` });

  /** 특정 유저의 알림 중 해당 type만 골라낸다. */
  async function notisOf(auth: Record<string, string>, type: string) {
    const res = await request(app.getHttpServer())
      .get('/notifications')
      .set(auth)
      .expect(200);
    return res.body.items.filter((n: any) => n.type === type);
  }

  it('친구 요청을 받으면 알림이 온다', async () => {
    await request(app.getHttpServer())
      .post('/friends/requests')
      .set(asMember())
      .send({ nickname: leaderNick })
      .expect(201);

    const notis = await notisOf(asLeader(), 'friend_request');
    expect(notis).toHaveLength(1);
    expect(notis[0].data.fromNickname).toBe(memberNick);
  });

  it('친구 요청이 수락되면 요청한 쪽에 알림이 온다', async () => {
    const reqs = await request(app.getHttpServer())
      .get('/friends/requests')
      .set(asLeader())
      .expect(200);
    const mine = reqs.body.items.find((r: any) => r.nickname === memberNick);
    await request(app.getHttpServer())
      .post(`/friends/requests/${mine.id}/accept`)
      .set(asLeader())
      .expect(201);

    const notis = await notisOf(asMember(), 'friend_accepted');
    expect(notis).toHaveLength(1);
  });

  it('크루 가입 신청이 오면 방장에게 알림이 온다', async () => {
    const crew = await request(app.getHttpServer())
      .post('/crews')
      .set(asLeader())
      .send({ name: `크루${Date.now().toString().slice(-6)}`, isPublic: true })
      .expect(201);
    crewId = crew.body.id;

    await request(app.getHttpServer())
      .post(`/crews/${crewId}/join-request`)
      .set(asMember())
      .expect(201);

    const notis = await notisOf(asLeader(), 'crew_join_request');
    expect(notis).toHaveLength(1);
    expect(notis[0].data.crewId).toBe(crewId);
  });

  it('가입 신청이 승인되면 신청자에게 알림이 온다', async () => {
    const reqs = await request(app.getHttpServer())
      .get(`/crews/${crewId}/join-requests`)
      .set(asLeader())
      .expect(200);
    const r = reqs.body.items[0];
    await request(app.getHttpServer())
      .post(`/crews/${crewId}/join-requests/${r.id}/accept`)
      .set(asLeader())
      .expect(201);

    const notis = await notisOf(asMember(), 'crew_join_result');
    expect(notis).toHaveLength(1);
    expect(notis[0].data.accepted).toBe('true');
  });

  it('내 글에 댓글이 달리면 글쓴이에게 알림이 온다', async () => {
    const post = await request(app.getHttpServer())
      .post(`/crews/${crewId}/posts`)
      .set(asLeader())
      .send({ message: '오늘도 달렸어요' })
      .expect(201);
    const postId = post.body.id;

    await request(app.getHttpServer())
      .post(`/crews/posts/${postId}/comments`)
      .set(asMember())
      .send({ text: '멋져요' })
      .expect(201);

    const notis = await notisOf(asLeader(), 'crew_comment');
    expect(notis).toHaveLength(1);
    expect(notis[0].body).toContain('멋져요');
  });

  it('글 응원은 토글을 반복해도 알림이 한 번만 생긴다', async () => {
    const post = await request(app.getHttpServer())
      .post(`/crews/${crewId}/posts`)
      .set(asLeader())
      .send({ message: '응원 테스트' })
      .expect(201);
    const postId = post.body.id;

    // 켜기 → 끄기 → 다시 켜기
    for (let i = 0; i < 3; i++) {
      await request(app.getHttpServer())
        .post(`/crews/posts/${postId}/cheer`)
        .set(asMember())
        .expect(201);
    }

    const notis = await notisOf(asLeader(), 'crew_post_cheer');
    const forThisPost = notis.filter((n: any) => n.data.postId === postId);
    expect(forThisPost).toHaveLength(1);
  });

  it('내 행동으로 나에게 알림이 오지는 않는다', async () => {
    const post = await request(app.getHttpServer())
      .post(`/crews/${crewId}/posts`)
      .set(asLeader())
      .send({ message: '자기 글 자기 댓글' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/crews/posts/${post.body.id}/comments`)
      .set(asLeader())
      .send({ text: '혼잣말' })
      .expect(201);

    const notis = await notisOf(asLeader(), 'crew_comment');
    const self = notis.filter((n: any) => n.data.postId === post.body.id);
    expect(self).toHaveLength(0);
  });
});
