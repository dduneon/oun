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

  it('시드된 데모유저를 친구로 추가한다', async () => {
    const res = await request(app.getHttpServer())
      .post('/friends')
      .set(auth())
      .send({ nickname: 'jimin' })
      .expect(201);
    expect(res.body.displayName).toBe('지민');

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
      .send({ name: 'e2e 크루', weeklyGoal: 3 })
      .expect(201);
    const crewId = crew.body.id;
    expect(crew.body.members).toHaveLength(1);
    expect(crew.body.level.level).toBe(1);

    await request(app.getHttpServer())
      .post(`/crews/${crewId}/members`)
      .set(auth())
      .send({ nickname: 'hyunwoo' })
      .expect(201);

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
});
