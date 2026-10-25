import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

/** 자격 로그인(아이디/비밀번호) e2e: 회원가입 → 로그인 → 오류 → refresh. */
describe('오운 인증 (e2e)', () => {
  let app: INestApplication;
  const suffix = Date.now().toString().slice(-8);
  const username = `user_${suffix}`;
  const displayName = '오운 러너';
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

  it('회원가입 → 아이디가 곧 @아이디, 닉네임은 화면 이름', async () => {
    const res = await http()
      .post('/auth/register')
      .send({ username: username.toUpperCase(), password, displayName, gender: 'm' })
      .expect(201);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
    expect(res.body.user.nickname).toBe(username); // 소문자로 통일
    expect(res.body.user.gender).toBe('m');
    const me = await http()
      .get('/me')
      .set({ Authorization: `Bearer ${res.body.accessToken}` })
      .expect(200);
    expect(me.body).toMatchObject({ nickname: username, displayName, handleConfirmed: true });
  });

  it('중복 아이디는 거절', async () => {
    await http()
      .post('/auth/register')
      .send({ username, password, displayName: '다른 사람', gender: 'f' })
      .expect(409);
  });

  it('짧은 비밀번호·한글이나 기호가 든 아이디는 검증 실패', async () => {
    for (const body of [
      { username: `u2_${suffix}`, password: '123' },
      { username: `한글${suffix}`, password },
      { username: 'ab', password },
      { username: `.dot${suffix}`, password },
      { username: `a..b${suffix}`, password },
    ]) {
      await http()
        .post('/auth/register')
        .send({ ...body, displayName, gender: 'f' })
        .expect(400);
    }
  });

  it('로그인: 올바른 비밀번호 → 성공, 틀리면 401', async () => {
    const ok = await http()
      .post('/auth/login')
      .send({ username: ` ${username.toUpperCase()} `, password })
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
