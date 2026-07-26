import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/**
 * 받은 응원 + 알림함 e2e: 응원의 수신자 측 동작을 검증한다.
 * (보내는 쪽 퀘스트 진행은 social.e2e-spec 담당)
 * 실행 전 docker compose up + migrate 필요.
 */
describe('오운 받은 응원·알림 (e2e)', () => {
  let app: INestApplication;
  let sender: string;
  let receiver: string;
  const senderNick = `snd_${Date.now().toString().slice(-9)}`;
  const receiverNick = `rcv_${Date.now().toString().slice(-9)}`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    const s = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: senderNick });
    sender = s.body.accessToken;
    const r = await request(app.getHttpServer())
      .post('/auth/dev')
      .send({ nickname: receiverNick });
    receiver = r.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  const asSender = () => ({ Authorization: `Bearer ${sender}` });
  const asReceiver = () => ({ Authorization: `Bearer ${receiver}` });

  it('응원을 받으면 받은 목록·미확인 수·알림함에 모두 남는다', async () => {
    const before = await request(app.getHttpServer())
      .get('/cheers/received')
      .set(asReceiver())
      .expect(200);
    expect(before.body.unseen).toBe(0);

    await request(app.getHttpServer())
      .post(`/users/${receiverNick}/cheer`)
      .set(asSender())
      .send({ emoji: '👏' })
      .expect(201);

    // 받은 응원 목록 — 보낸 사람과 이모지가 보인다
    const after = await request(app.getHttpServer())
      .get('/cheers/received')
      .set(asReceiver())
      .expect(200);
    expect(after.body.unseen).toBe(1);
    expect(after.body.items[0].emoji).toBe('👏');
    expect(after.body.items[0].fromNickname).toBe(senderNick);
    expect(after.body.items[0].seen).toBe(false);

    // 같은 응원이 인앱 알림함에도 쌓인다
    const notis = await request(app.getHttpServer())
      .get('/notifications')
      .set(asReceiver())
      .expect(200);
    expect(notis.body.unread).toBe(1);
    expect(notis.body.items[0].type).toBe('cheer');
    expect(notis.body.items[0].read).toBe(false);
  });

  it('확인 처리하면 미확인 수가 0이 된다(목록은 남는다)', async () => {
    await request(app.getHttpServer())
      .post('/cheers/received/seen')
      .set(asReceiver())
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/cheers/received')
      .set(asReceiver())
      .expect(200);
    expect(res.body.unseen).toBe(0);
    expect(res.body.items.length).toBeGreaterThan(0);
    expect(res.body.items[0].seen).toBe(true);
  });

  it('알림을 읽음 처리하면 안 읽은 수가 0이 된다', async () => {
    const res = await request(app.getHttpServer())
      .post('/notifications/read')
      .set(asReceiver())
      .send({})
      .expect(201);
    expect(res.body.unread).toBe(0);

    const count = await request(app.getHttpServer())
      .get('/notifications/unread-count')
      .set(asReceiver())
      .expect(200);
    expect(count.body.unread).toBe(0);
  });

  it('보낸 사람 알림함에는 쌓이지 않는다(수신자 전용)', async () => {
    const res = await request(app.getHttpServer())
      .get('/notifications')
      .set(asSender())
      .expect(200);
    expect(res.body.items.filter((n: any) => n.type === 'cheer')).toHaveLength(0);
  });

  it('푸시 토큰을 등록·해제할 수 있다', async () => {
    const token = `tok_${Date.now()}`;
    await request(app.getHttpServer())
      .post('/devices')
      .set(asReceiver())
      .send({ token, platform: 'ios' })
      .expect(201);

    // 멱등: 같은 토큰 재등록도 성공
    await request(app.getHttpServer())
      .post('/devices')
      .set(asReceiver())
      .send({ token, platform: 'ios' })
      .expect(201);

    await request(app.getHttpServer())
      .delete(`/devices/${token}`)
      .set(asReceiver())
      .expect(200);
  });
});
