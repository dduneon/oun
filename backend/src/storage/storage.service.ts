import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'minio';
import { randomUUID } from 'crypto';

/**
 * MinIO(S3 호환) 오브젝트 스토리지. 운동 인증 사진 등을 보관한다.
 * - 업로드: presigned PUT URL을 발급해 앱이 MinIO로 직접 올린다(서버 경유 X).
 * - 조회: 버킷을 공개 읽기로 두고 공개 URL로 표시(키는 uuid라 추측이 어렵다).
 */
@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: Client;
  private readonly bucket: string;
  private readonly publicUrl: string;

  constructor(private readonly config: ConfigService) {
    this.bucket = config.get<string>('MINIO_BUCKET') ?? 'oun';
    this.publicUrl = (
      config.get<string>('MINIO_PUBLIC_URL') ?? 'http://localhost:9000'
    ).replace(/\/$/, '');
    this.client = new Client({
      endPoint: config.get<string>('MINIO_ENDPOINT') ?? 'localhost',
      port: Number(config.get<string>('MINIO_PORT') ?? 9000),
      useSSL: (config.get<string>('MINIO_USE_SSL') ?? 'false') === 'true',
      accessKey: config.get<string>('MINIO_ACCESS_KEY') ?? 'oun',
      secretKey: config.get<string>('MINIO_SECRET_KEY') ?? 'oun_dev_pw',
    });
  }

  /** 버킷 없으면 생성 + 공개 읽기 정책 적용. MinIO가 아직 안 떠 있어도 서버는 계속 뜬다. */
  async onModuleInit() {
    try {
      const exists = await this.client.bucketExists(this.bucket);
      if (!exists) {
        await this.client.makeBucket(this.bucket);
        this.logger.log(`버킷 생성: ${this.bucket}`);
      }
      await this.client.setBucketPolicy(this.bucket, this.publicReadPolicy());
    } catch (e) {
      this.logger.warn(
        `MinIO 초기화 실패(스토리지 없이 계속 진행): ${String(e)}`,
      );
    }
  }

  private publicReadPolicy(): string {
    return JSON.stringify({
      Version: '2012-10-17',
      Statement: [
        {
          Effect: 'Allow',
          Principal: { AWS: ['*'] },
          Action: ['s3:GetObject'],
          Resource: [`arn:aws:s3:::${this.bucket}/*`],
        },
      ],
    });
  }

  /** 운동 사진 업로드용 presigned PUT URL 발급. 키는 서버가 정한다(5분 유효). */
  async presignWorkoutPhoto(userId: string, contentType: string) {
    const ext = contentType.includes('png') ? 'png' : 'jpg';
    const key = `workouts/${userId}/${randomUUID()}.${ext}`;
    const uploadUrl = await this.client.presignedPutObject(
      this.bucket,
      key,
      5 * 60,
    );
    return { key, uploadUrl };
  }

  /** 저장된 키의 공개 조회 URL. 키가 없으면 null. */
  publicUrlFor(key?: string | null): string | null {
    if (!key) return null;
    return `${this.publicUrl}/${this.bucket}/${key}`;
  }
}
