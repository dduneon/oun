import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/** 내 크루 글 수정·삭제, 내 운동 기록 삭제(코인 회수) e2e. */
describe('오운 수정·삭제 (e2e)', () => {
  let app: INestApplication;
  let token: string;
  const nickname = `mut_${Date.now().toString().slice(-9)}`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
    const res = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname });
    token = res.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  const auth = () => ({ Authorization: `Bearer ${token}` });

  it('운동 기록 삭제 → 지급된 코인이 회수된다', async () => {
    const before = (
      await request(app.getHttpServer()).get('/wallet').set(auth()).expect(200)
    ).body.balance as number;

    const created = await request(app.getHttpServer())
      .post('/workouts')
      .set(auth())
      .send({ sport: 'running', durationSec: 1500, distanceM: 4000 })
      .expect(201);
    expect(created.body.verified).toBe(true);
    const reward = created.body.reward as number;
    expect(reward).toBeGreaterThan(0);

    const afterCreate = (
      await request(app.getHttpServer()).get('/wallet').set(auth()).expect(200)
    ).body.balance as number;
    expect(afterCreate).toBe(before + reward);

    // 삭제 → 회수
    const del = await request(app.getHttpServer())
      .delete(`/workouts/${created.body.workout.id}`)
      .set(auth())
      .expect(200);
    expect(del.body.deleted).toBe(true);
    expect(del.body.balance).toBe(before);

    const list = await request(app.getHttpServer())
      .get('/workouts')
      .set(auth())
      .expect(200);
    expect(list.body.items.some((w: any) => w.id === created.body.workout.id))
      .toBe(false);
  });

  it('크루 글 수정 → 삭제', async () => {
    const crew = await request(app.getHttpServer())
      .post('/crews')
      .set(auth())
      .send({ name: `mut크루_${Date.now().toString().slice(-6)}` })
      .expect(201);
    const crewId = crew.body.id;

    const post = await request(app.getHttpServer())
      .post(`/crews/${crewId}/posts`)
      .set(auth())
      .send({ message: '처음 글' })
      .expect(201);
    const postId = post.body.id;

    // 수정
    await request(app.getHttpServer())
      .patch(`/crews/posts/${postId}`)
      .set(auth())
      .send({ message: '수정된 글' })
      .expect(200);
    let feed = await request(app.getHttpServer())
      .get(`/crews/${crewId}/feed`)
      .set(auth())
      .expect(200);
    expect(feed.body.items[0].message).toBe('수정된 글');

    // 삭제
    await request(app.getHttpServer())
      .delete(`/crews/posts/${postId}`)
      .set(auth())
      .expect(200);
    feed = await request(app.getHttpServer())
      .get(`/crews/${crewId}/feed`)
      .set(auth())
      .expect(200);
    expect(feed.body.items).toHaveLength(0);
  });

  it('남의 글은 수정·삭제할 수 없다', async () => {
    const crew = await request(app.getHttpServer())
      .post('/crews')
      .set(auth())
      .send({ name: `mut크루2_${Date.now().toString().slice(-6)}` })
      .expect(201);
    const post = await request(app.getHttpServer())
      .post(`/crews/${crew.body.id}/posts`)
      .set(auth())
      .send({ message: '내 글' })
      .expect(201);

    const other = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: `other_${Date.now().toString().slice(-8)}` });
    const oAuth = { Authorization: `Bearer ${other.body.accessToken}` };

    await request(app.getHttpServer())
      .delete(`/crews/posts/${post.body.id}`)
      .set(oAuth)
      .expect(403);
  });
});
