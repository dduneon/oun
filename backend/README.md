# 오운(Oun) 백엔드

NestJS + Prisma + MariaDB API 서버. 구현된 Flutter 앱 화면이 필요로 하는 데이터를 제공한다.
**서버가 재화·상태의 source of truth**이며, 클라이언트는 표현만 담당한다.

## 빠른 시작

```bash
cp .env.example .env
docker compose up -d          # MariaDB + Redis
npm install
npx prisma migrate dev        # 스키마 적용
npm run prisma:seed           # 상점/퀘스트/업적 정의 시드
npm run start:dev             # http://localhost:3000
```

## 스택
- NestJS (모듈별 도메인 분리) + REST
- Prisma ORM / MariaDB 11 (`mysql` 프로바이더)
- JWT (access/refresh), 카카오 로그인 + 개발용 dev 로그인 스텁
- Redis (다음 단계: 세션/실시간 크루 라운지 대비, 현재 미사용)

## 구현 범위
인증 · 지갑(재화 원장) · 운동 기록/검증/보상 · 캐릭터 스탯/mood · 퀘스트 · 상점/인벤토리/장착 · 업적 ·
**소셜(친구·응원) · 크루(생성·초대·피드·댓글·레벨 보상)**.
크루 라운지 실시간 프레즌스/WebSocket, HealthKit/Health Connect 실검증은 다음 단계.

## 핵심 원칙
- 모든 재화 증감은 `CurrencyLedger`에 append + **멱등키 + 트랜잭션**으로만 (어뷰징/중복 보상 차단).
- 잔액 = 최신 `balanceAfter`. 클라이언트에서 재화 계산 금지.
- 상점 아이템은 기능 스탯 0 (순수 치장).

## 엔드포인트 요약
| 도메인 | 엔드포인트 |
| :-- | :-- |
| 인증 | `POST /auth/kakao`, `POST /auth/dev`, `POST /auth/refresh` |
| 프로필 | `GET /me`, `PATCH /me` |
| 지갑 | `GET /wallet` |
| 운동 | `POST /workouts`, `GET /workouts`, `GET /workouts/calendar`, `GET /workouts/summary` |
| 캐릭터 | `GET /character`, `GET /character/mood` |
| 퀘스트 | `GET /quests`, `POST /quests/:key/claim` |
| 상점 | `GET /shop/items`, `POST /shop/orders`, `GET /inventory`, `PUT /character/equip` |
| 업적 | `GET /achievements` |
| 친구 | `GET /friends`, `POST /friends`, `GET /users/:nickname/home`, `POST /users/:nickname/cheer` |
| 크루 | `POST /crews`, `GET /crews`, `GET /crews/:id`, `POST /crews/:id/members`, `DELETE /crews/:id/members/me` |
| 크루 피드 | `GET /crews/:id/feed`, `POST /crews/posts/:postId/comments`, `POST /crews/posts/:postId/cheer` |
| 크루 보상 | `GET /crews/:id/rewards`, `POST /crews/:id/rewards/:level/claim` |
| 헬스체크 | `GET /health` |

> 운동이 검증되면 소속 크루 피드에 자동 공유되고, 크루 레벨(누적 운동 횟수)이 오른다.
> 개발 편의를 위해 `prisma db seed`가 데모 친구(지민·현우·서연·민준)를 만든다 — `@jimin` 등으로 친구 추가·초대 가능.
