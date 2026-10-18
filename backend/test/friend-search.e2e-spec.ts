import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/** 친구 찾기: 닉네임 검색 목록과 프로필 카드(관계에 따라 버튼이 갈린다). */
describe('친구 찾기 (e2e)', () => {
  let app: INestApplication;
  const s = Date.now() % 1e6;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());
  async function login(nickname: string) {
    const res = await http().post('/auth/dev').send({ nickname }).expect(201);
    return { Authorization: `Bearer ${res.body.accessToken}` };
  }

  it('검색: 정확히 맞는 닉네임이 먼저, 나는 빼고, 관계를 함께 준다', async () => {
    const me = await login(`fs${s}`);
    const a = await login(`fs${s}a`);
    await login(`fs${s}ab`);

    const res = await http().get(`/users/search?q=fs${s}a`).set(me).expect(200);
    expect(res.body.items.map((u: { nickname: string }) => u.nickname)).toEqual([`fs${s}a`, `fs${s}ab`]);
    expect(res.body.items[0]).toMatchObject({ relation: 'none', gender: 'f' });
    expect(res.body.items[0].equipment).toEqual({});

    // a가 나에게 요청 → 내 검색에서 a는 incoming(수락할 요청 id 포함)
    await http().post('/friends/requests').set(a).send({ nickname: `fs${s}` }).expect(201);
    const after = await http().get(`/users/search?q=@fs${s}a`).set(me).expect(200);
    expect(after.body.items[0].relation).toBe('incoming');
    expect(after.body.items[0].requestId).toBeTruthy();

    // 반대로 a 입장에서 나는 requested
    const fromA = await http().get(`/users/fs${s}/profile`).set(a).expect(200);
    expect(fromA.body).toMatchObject({ relation: 'requested', level: 1, streakCurrent: 0 });
    expect(fromA.body.recent).toBeUndefined(); // 친구가 아니면 운동 기록은 없다

    // 수락하면 친구
    await http().post(`/friends/requests/${after.body.items[0].requestId}/accept`).set(me).expect(201);
    const friend = await http().get(`/users/fs${s}a/profile`).set(me).expect(200);
    expect(friend.body.relation).toBe('friend');

    const self = await http().get(`/users/fs${s}/profile`).set(me).expect(200);
    expect(self.body.relation).toBe('me');
    await http().get(`/users/nobody_${s}/profile`).set(me).expect(404);
    expect((await http().get('/users/search?q=').set(me).expect(200)).body.items).toEqual([]);
  });
});
