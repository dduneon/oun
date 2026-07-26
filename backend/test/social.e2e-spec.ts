import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/**
 * 소셜/크루 e2e: 친구 추가·응원 → 크루 생성·초대 → 운동 자동 공유 →
 * 피드·댓글·응원. 실행 전 docker compose up + migrate + seed(데모유저) 필요.
 */
describe('오운 소셜·크루 (e2e)', () => {
  let app: INestApplication;
  let token: string;
  const nickname = `soc_${Date.now().toString().slice(-9)}`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    const res = await request(app.getHttpServer()).post('/auth/dev').send({ nickname });
    token = res.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  const auth = () => ({ Authorization: `Bearer ${token}` });

  it('친구 요청 → 상대가 수락 → 친구가 된다', async () => {
    // 내가 jimin에게 요청(수락 전까진 친구 아님)
    const res = await request(app.getHttpServer())
      .post('/friends/requests')
      .set(auth())
      .send({ nickname: 'jimin' })
      .expect(201);
    expect(res.body.status).toBe('requested');

    const before = await request(app.getHttpServer()).get('/friends').set(auth()).expect(200);
    expect(before.body.items.map((f: any) => f.nickname)).not.toContain('jimin');

    // jimin 로그인 → 받은 요청 확인 → 수락
    const jimin = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: 'jimin' });
    const jAuth = { Authorization: `Bearer ${jimin.body.accessToken}` };
    const reqs = await request(app.getHttpServer())
      .get('/friends/requests')
      .set(jAuth)
      .expect(200);
    const mine = reqs.body.items.find((r: any) => r.nickname === nickname);
    expect(mine).toBeTruthy();
    await request(app.getHttpServer())
      .post(`/friends/requests/${mine.id}/accept`)
      .set(jAuth)
      .expect(201);

    // 이제 서로 친구 목록에 노출
    const list = await request(app.getHttpServer()).get('/friends').set(auth()).expect(200);
    expect(list.body.items.map((f: any) => f.nickname)).toContain('jimin');
  });

  it('친구에게 응원 → weekly_cheer 퀘스트 진행', async () => {
    await request(app.getHttpServer())
      .post('/users/jimin/cheer')
      .set(auth())
      .send({ emoji: '👏' })
      .expect(201);
    const quests = await request(app.getHttpServer()).get('/quests').set(auth()).expect(200);
    const cheerQuest = quests.body.weekly.find((q: any) => q.key === 'weekly_cheer');
    expect(cheerQuest.progress).toBeGreaterThanOrEqual(1);
  });

  it('친구 홈을 조회한다', async () => {
    const res = await request(app.getHttpServer())
      .get('/users/jimin/home')
      .set(auth())
      .expect(200);
    expect(res.body.nickname).toBe('jimin');
    expect(res.body.weekDone).toHaveLength(7);
    expect(res.body.recent.length).toBeGreaterThan(0);
  });

  it('크루 생성 → 초대 → 운동을 태그해 직접 피드에 올린다', async () => {
    const crew = await request(app.getHttpServer())
      .post('/crews')
      .set(auth())
      .send({ name: 'e2e 크루', description: '테스트 크루예요', isPublic: true })
      .expect(201);
    const crewId = crew.body.id;
    expect(crew.body.members).toHaveLength(1);
    expect(crew.body.level.level).toBe(1);
    expect(crew.body.isLeader).toBe(true);

    // 초대는 즉시 추가가 아니라 대기중 초대를 만든다.
    await request(app.getHttpServer())
      .post(`/crews/${crewId}/invite`)
      .set(auth())
      .send({ nickname: 'hyunwoo' })
      .expect(201);
    const stillSolo = await request(app.getHttpServer())
      .get(`/crews/${crewId}`)
      .set(auth())
      .expect(200);
    expect(stillSolo.body.members).toHaveLength(1); // 수락 전까지는 그대로

    // 운동 기록 (이 시점엔 피드에 자동 공유되지 않는다)
    const workout = await request(app.getHttpServer())
      .post('/workouts')
      .set(auth())
      .send({ sport: 'running', durationSec: 1500, distanceM: 4000 })
      .expect(201);
    const workoutId = workout.body.workout.id;

    let feed = await request(app.getHttpServer())
      .get(`/crews/${crewId}/feed`)
      .set(auth())
      .expect(200);
    expect(feed.body.items).toHaveLength(0); // 자동 공유 없음

    // 운동을 태그해 직접 글 작성
    await request(app.getHttpServer())
      .post(`/crews/${crewId}/posts`)
      .set(auth())
      .send({ workoutLogId: workoutId, message: '오늘 한강 뛰었어요' })
      .expect(201);

    // 같은 운동 중복 공유는 거절
    await request(app.getHttpServer())
      .post(`/crews/${crewId}/posts`)
      .set(auth())
      .send({ workoutLogId: workoutId })
      .expect(409);

    // 운동 태그 없이 글만도 가능
    await request(app.getHttpServer())
      .post(`/crews/${crewId}/posts`)
      .set(auth())
      .send({ message: '다들 화이팅!' })
      .expect(201);

    feed = await request(app.getHttpServer())
      .get(`/crews/${crewId}/feed`)
      .set(auth())
      .expect(200);
    expect(feed.body.items).toHaveLength(2);
    const tagged = feed.body.items.find((p: any) => p.workout != null);
    expect(tagged.message).toBe('오늘 한강 뛰었어요');
    expect(tagged.author.isMe).toBe(true);
    const textOnly = feed.body.items.find((p: any) => p.workout == null);
    expect(textOnly.message).toBe('다들 화이팅!');

    // 댓글 + 응원 토글
    const comment = await request(app.getHttpServer())
      .post(`/crews/posts/${tagged.id}/comments`)
      .set(auth())
      .send({ text: '화이팅!' })
      .expect(201);
    expect(comment.body.text).toBe('화이팅!');

    const cheer = await request(app.getHttpServer())
      .post(`/crews/posts/${tagged.id}/cheer`)
      .set(auth())
      .expect(201);
    expect(cheer.body.cheered).toBe(true);
    expect(cheer.body.cheers).toBe(1);
  });

  it('내 크루 목록에 노출된다', async () => {
    const res = await request(app.getHttpServer()).get('/crews').set(auth()).expect(200);
    expect(res.body.items.some((c: any) => c.name === 'e2e 크루')).toBe(true);
  });

  it('초대 → 수락 → 크루원이 된다', async () => {
    const crew = await request(app.getHttpServer())
      .post('/crews')
      .set(auth())
      .send({ name: 'invite 크루', isPublic: false })
      .expect(201);
    const crewId = crew.body.id;

    // hyunwoo 초대
    await request(app.getHttpServer())
      .post(`/crews/${crewId}/invite`)
      .set(auth())
      .send({ nickname: 'hyunwoo' })
      .expect(201);

    // hyunwoo 로그인 → 받은 초대 확인 → 수락
    const hyunwoo = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: 'hyunwoo' });
    const hAuth = { Authorization: `Bearer ${hyunwoo.body.accessToken}` };

    const invites = await request(app.getHttpServer())
      .get('/crews/invitations')
      .set(hAuth)
      .expect(200);
    const inv = invites.body.items.find((i: any) => i.crewId === crewId);
    expect(inv).toBeTruthy();

    await request(app.getHttpServer())
      .post(`/crews/invitations/${inv.id}/accept`)
      .set(hAuth)
      .expect(201);

    const detail = await request(app.getHttpServer())
      .get(`/crews/${crewId}`)
      .set(auth())
      .expect(200);
    expect(detail.body.members).toHaveLength(2);
  });

  it('공개 크루 탐방 → 가입 신청 → 방장 승인', async () => {
    // seoyeon이 공개 크루를 만든다.
    const seoyeon = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: 'seoyeon' });
    const sAuth = { Authorization: `Bearer ${seoyeon.body.accessToken}` };
    const crew = await request(app.getHttpServer())
      .post('/crews')
      .set(sAuth)
      .send({ name: `공개크루_${Date.now().toString().slice(-6)}`, isPublic: true })
      .expect(201);
    const crewId = crew.body.id;

    // 나(soc_*)는 탐방에서 그 크루를 보고 가입 신청.
    const discover = await request(app.getHttpServer())
      .get('/crews/discover')
      .set(auth())
      .expect(200);
    expect(discover.body.items.some((c: any) => c.id === crewId)).toBe(true);

    await request(app.getHttpServer())
      .post(`/crews/${crewId}/join-request`)
      .set(auth())
      .expect(201);

    // 방장(seoyeon)이 신청을 보고 승인.
    const reqs = await request(app.getHttpServer())
      .get(`/crews/${crewId}/join-requests`)
      .set(sAuth)
      .expect(200);
    expect(reqs.body.items).toHaveLength(1);

    await request(app.getHttpServer())
      .post(`/crews/${crewId}/join-requests/${reqs.body.items[0].id}/accept`)
      .set(sAuth)
      .expect(201);

    const detail = await request(app.getHttpServer())
      .get(`/crews/${crewId}`)
      .set(sAuth)
      .expect(200);
    expect(detail.body.members).toHaveLength(2);

    // 합류하면 피드에 시스템 글이 남고, 응원·댓글은 일반 글과 똑같이 된다.
    const feed = await request(app.getHttpServer())
      .get(`/crews/${crewId}/feed`)
      .set(sAuth)
      .expect(200);
    const joinPost = feed.body.items.find((p: any) => p.kind === 'join');
    expect(joinPost).toBeTruthy();
    expect(joinPost.author.isMe).toBe(false); // 방장이 보면 새 크루원의 글
    expect(joinPost.workout).toBeNull();

    await request(app.getHttpServer())
      .post(`/crews/posts/${joinPost.id}/cheer`)
      .set(sAuth)
      .expect(201);
    await request(app.getHttpServer())
      .post(`/crews/posts/${joinPost.id}/comments`)
      .set(sAuth)
      .send({ text: '어서 와요!' })
      .expect(201);

    const after = await request(app.getHttpServer())
      .get(`/crews/${crewId}/feed`)
      .set(auth())
      .expect(200);
    const mine = after.body.items.find((p: any) => p.id === joinPost.id);
    expect(mine.cheers).toBe(1);
    expect(mine.comments).toHaveLength(1);
    expect(mine.author.isMe).toBe(true);

    // 시스템 글은 본인 글이어도 수정·삭제 불가.
    await request(app.getHttpServer())
      .patch(`/crews/posts/${joinPost.id}`)
      .set(auth())
      .send({ message: '바꿔보기' })
      .expect(403);
    await request(app.getHttpServer())
      .delete(`/crews/posts/${joinPost.id}`)
      .set(auth())
      .expect(403);
  });
});
