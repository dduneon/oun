import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import axios from 'axios';
import { AppModule } from '../src/app.module';

/**
 * 운동 사진 업로드 e2e: presigned URL 발급 → MinIO 직접 업로드 →
 * 워크아웃에 photoRef 첨부 → 목록에서 photoUrl 확인 → 공개 URL 조회.
 * 실행 전 docker compose up(minio 포함) 필요.
 */
describe('운동 사진 업로드 (e2e)', () => {
  let app: INestApplication;
  let token: string;
  const nickname = `photo_${Date.now().toString().slice(-9)}`;

  // 1x1 투명 PNG
  const pngBytes = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    'base64',
  );

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
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

  it('presigned URL 발급 → 업로드 → 워크아웃 첨부 → 조회', async () => {
    // 1) presigned PUT URL 발급
    const presign = await request(app.getHttpServer())
      .post('/uploads/workout-photo')
      .set(auth())
      .send({ contentType: 'image/png' })
      .expect(201);
    expect(presign.body.key).toMatch(/^workouts\//);
    expect(presign.body.uploadUrl).toContain(presign.body.key);

    // 2) MinIO로 직접 업로드
    await axios.put(presign.body.uploadUrl, pngBytes, {
      headers: { 'Content-Type': 'image/png' },
    });

    // 3) 워크아웃에 photoRef 첨부
    await request(app.getHttpServer())
      .post('/workouts')
      .set(auth())
      .send({ sport: 'running', durationSec: 1500, photoRef: presign.body.key })
      .expect(201);

    // 4) 목록에서 photoUrl 확인
    const list = await request(app.getHttpServer())
      .get('/workouts')
      .set(auth())
      .expect(200);
    const withPhoto = list.body.items.find(
      (w: any) => w.photoRef === presign.body.key,
    );
    expect(withPhoto).toBeTruthy();
    expect(withPhoto.photoUrl).toContain(presign.body.key);

    // 5) 공개 URL로 실제 조회 가능
    const download = await axios.get(withPhoto.photoUrl, {
      responseType: 'arraybuffer',
    });
    expect(download.status).toBe(200);
    expect(download.data.byteLength).toBe(pngBytes.byteLength);
  });
});
