import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { generateKeyPairSync } from 'crypto';
import * as jwt from 'jsonwebtoken';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { AppleTokenVerifier } from '../src/auth/apple-token.verifier';

/**
 * 애플 로그인 e2e. 애플 공개키 대신 테스트 키쌍을 끼워 넣고 identity token을 직접 서명한다.
 */
describe('애플 로그인 (e2e)', () => {
  let app: INestApplication;
  const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const kid = 'test-kid';
  const sub = `apple.${Date.now()}`;

  const token = (opts: { aud?: string; iss?: string; sub?: string } = {}) =>
    jwt.sign({}, privateKey, {
      algorithm: 'RS256',
      keyid: kid,
      issuer: opts.iss ?? 'https://appleid.apple.com',
      audience: opts.aud ?? 'com.dduneon.oun',
      subject: opts.sub ?? sub,
      expiresIn: '5m',
    });

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    jest
      .spyOn(app.get(AppleTokenVerifier), 'fetchKeys')
      .mockResolvedValue([{ ...publicKey.export({ format: 'jwk' }), kid }]);
  });

  afterAll(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());

  it('처음이면 계정을 만들고 isNew, 닉네임은 규칙에 맞게 다듬는다', async () => {
    const res = await http()
      .post('/auth/apple')
      .send({ identityToken: token(), displayName: '애플 오운!' })
      .expect(201);
    expect(res.body.isNew).toBe(true);
    expect(res.body.user.nickname).toMatch(/^애플오운/);

    const auth = { Authorization: `Bearer ${res.body.accessToken}` };
    const me = await http().get('/me').set(auth).expect(200);
    expect(me.body.displayName).toBe('애플 오운!');
    // 첫 가입 화면에서 캐릭터를 고른다.
    const updated = await http().patch('/me').set(auth).send({ gender: 'm' }).expect(200);
    expect(updated.body.gender).toBe('m');
  });

  it('두 번째부터는 같은 계정으로 들어온다', async () => {
    const res = await http().post('/auth/apple').send({ identityToken: token() }).expect(201);
    expect(res.body.isNew).toBe(false);
    expect(res.body.user.gender).toBe('m');
  });

  it('다른 앱용 토큰·위조 발급자는 막는다', async () => {
    await http().post('/auth/apple').send({ identityToken: token({ aud: 'com.other.app' }) }).expect(401);
    await http().post('/auth/apple').send({ identityToken: token({ iss: 'https://evil.example' }) }).expect(401);
    await http().post('/auth/apple').send({ identityToken: 'not-a-jwt' }).expect(401);
  });
});
