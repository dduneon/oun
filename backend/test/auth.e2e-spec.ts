import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/** 자격 로그인(아이디/비밀번호) e2e: 회원가입 → 로그인 → 오류 → refresh. */
describe('오운 인증 (e2e)', () => {
  let app: INestApplication;
  const suffix = Date.now().toString().slice(-8);
  const username = `user_${suffix}`;
  const nickname = `nick_${suffix}`;
  const password = 'secret123';

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());

  it('회원가입 → 토큰 + 프로필 발급', async () => {
    const res = await http()
      .post('/auth/register')
      .send({ username, password, nickname, gender: 'm' })
      .expect(201);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
    expect(res.body.user.nickname).toBe(nickname);
    expect(res.body.user.gender).toBe('m');
  });

  it('중복 아이디는 거절', async () => {
    await http()
      .post('/auth/register')
      .send({ username, password, nickname: `${nickname}_2`, gender: 'f' })
      .expect(409);
  });

  it('짧은 비밀번호는 검증 실패', async () => {
    await http()
      .post('/auth/register')
      .send({ username: `u2_${suffix}`, password: '123', nickname: `n2_${suffix}`, gender: 'f' })
      .expect(400);
  });

  it('로그인: 올바른 비밀번호 → 성공, 틀리면 401', async () => {
    const ok = await http()
      .post('/auth/login')
      .send({ username, password })
      .expect(201);
    expect(ok.body.accessToken).toBeTruthy();

    await http()
      .post('/auth/login')
      .send({ username, password: 'wrongpass' })
      .expect(401);
  });

  it('refresh 토큰으로 새 액세스 토큰 발급', async () => {
    const login = await http()
      .post('/auth/login')
      .send({ username, password })
      .expect(201);
    const refreshed = await http()
      .post('/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(201);
    expect(refreshed.body.accessToken).toBeTruthy();
  });
});
