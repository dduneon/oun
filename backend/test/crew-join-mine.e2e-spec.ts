import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/** 내가 신청하고 기다리는 크루: 목록·취소·승인되면 사라짐. */
describe('내 크루 가입 신청 (e2e)', () => {
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

  it('신청한 크루가 대기 목록에 뜨고, 취소하거나 승인되면 빠진다', async () => {
    const leader = await login(`jl${s}`);
    const me = await login(`jm${s}`);
    const a = (await http().post('/crews').set(leader).send({ name: `대기A${s}` }).expect(201)).body.id;
    const b = (await http().post('/crews').set(leader).send({ name: `대기B${s}` }).expect(201)).body.id;

    await http().post(`/crews/${a}/join-request`).set(me).expect(201);
    await http().post(`/crews/${b}/join-request`).set(me).expect(201);

    let mine = await http().get('/crews/join-requests/mine').set(me).expect(200);
    expect(mine.body.items.map((c: { id: string }) => c.id).sort()).toEqual([a, b].sort());
    expect(mine.body.items[0]).toMatchObject({ memberCount: 1, isPublic: true });
    expect(mine.body.items[0].level.level).toBe(1);

    // 취소
    await http().delete(`/crews/${a}/join-request`).set(me).expect(200);
    await http().delete(`/crews/${a}/join-request`).set(me).expect(404);

    // 방장이 승인하면 대기 목록에서 빠지고 내 크루가 된다
    const reqs = await http().get(`/crews/${b}/join-requests`).set(leader).expect(200);
    await http().post(`/crews/${b}/join-requests/${reqs.body.items[0].id}/accept`).set(leader).expect(201);
    mine = await http().get('/crews/join-requests/mine').set(me).expect(200);
    expect(mine.body.items).toEqual([]);
    const crews = await http().get('/crews').set(me).expect(200);
    expect(crews.body.items.map((c: { id: string }) => c.id)).toContain(b);
  });
});
