# 오운(Oun) 개발 실행 플랜 (B안: Flutter + Unity as a Library)

- **기준 문서:** `service_development_plan_oun.md`
- **아키텍처 확정:** B안 — Flutter 앱 셸 + Unity(UaaL) 3D 임베드
- **작성일:** 2026-07-13
- **버전:** v1.1 (실행 상세)

### 확정된 초기 방향
- **과금 모델:** 무과금 — **운동으로 얻는 인게임 재화만** 사용. 초기엔 IAP(인앱결제) 연동 배제, 이후 확장 여지만 열어둠.
- **출시 범위:** **한국 우선.** 한국어 단일 로케일 + 국내 리전으로 먼저 출시, i18n 구조만 미리 잡아 글로벌 확장 대비.
- **아트 에셋:** **내재화.** 사내 3D 아티스트가 캐릭터·아이템·마이룸 제작. 장기 시즌 운영에 유리한 대신 초기 채용/셋업 시간 확보 필요.

---

## 1. 아키텍처 개요

```
┌───────────────────────────────────────────────┐
│                 Flutter App Shell               │
│  (라우팅, 피드, 상점 UI, 크루, 설정, 리포트)     │
│                                                 │
│   ┌─────────────────────────────────────────┐  │
│   │   UaaL 브릿지 (MethodChannel / JSON msg) │  │
│   └───────────────┬─────────────────────────┘  │
│                   │                             │
│   ┌───────────────▼─────────────────────────┐  │
│   │   Unity View (URP 툰셰이딩)              │  │
│   │   - 캐릭터/마이룸 3D 씬                   │  │
│   │   - 아이템 장착/애니메이션               │  │
│   │   - Addressables 원격 에셋               │  │
│   └─────────────────────────────────────────┘  │
│                                                 │
│   HealthKit / Health Connect 플러그인 (네이티브) │
└───────────────────────────┬─────────────────────┘
                            │ HTTPS / WSS
              ┌─────────────▼──────────────┐
              │        Backend             │
              │  API(NestJS) + WS + Worker │
              │   MariaDB / Redis / S3     │
              └────────────────────────────┘
```

### 역할 분담 원칙
- **Flutter가 담당:** 로그인, 하단 탭 네비게이션, 운동 기록 입력 폼, 상점 리스트/결제 UI, 소셜 피드, 크루 라운지 UI, 설정, 리포트 카드. → 앱 화면의 약 70%
- **Unity가 담당:** 캐릭터·마이룸 3D 렌더링, 아이템 장착 프리뷰, 희귀 아이템 특수 이펙트, 카메라/터치 인터랙션. → 3D 씬만
- **통신:** Flutter → Unity `sendMessage(json)` / Unity → Flutter `MethodChannel` 콜백. **상태의 원본(source of truth)은 항상 서버**, Unity는 표현만 담당.

---

## 1.5 핵심 경험 설계: 살아있는 반려 캐릭터

오운의 캐릭터는 "커스터마이징 대상 아바타"에 그치지 않고 **운동 습관에 반응하는 살아있는 반려 존재**로 설계한다. 이것이 여타 기록 앱과의 핵심 차별점이며, 계획서의 "감성적 / 칭찬과 독려" 가치를 시각적으로 구현하는 축이다. 두 갈래로 나눈다.

### A. 내 캐릭터의 상태 표현 (다마고치형) — 우선 구현, MVP
- **홈 화면 상시 렌더링:** 앱 실행 시 홈에 내 캐릭터가 살아있는 상태로 존재(UaaL 임베드).
- **운동 상태에 따른 반응:** 마지막 운동 시각·누적 상태 수치를 기준으로 표정·모션·말풍선 변화.
  - 예) 오래 안 하면 "배고파/시무룩", 운동 직후 "활기참/뿌듯", Streak 유지 중 "신남".
- **표정은 텍스처(데칼) 교체로 처리** — 지오메트리 변형 없이 표정 전환 → 애니메이션 단순화 + AI 3D 생성의 얼굴 왜곡 회피.
- **부담 낮음:** 서버의 "마지막 운동 시각 + 상태 수치"만 있으면 클라이언트가 표현. 혼자서도 구현 가능하며 "내 캐릭터가 살아있다"는 감성의 대부분을 여기서 확보.
- **주의(착한 게이미피케이션 준수):** 부정적 상태는 죄책감을 주지 않는 선(귀여운 시무룩 정도)으로 톤 제한. 방치해도 **캐릭터가 아프거나 죽지 않음**. Rest Day/기록 보호권과 연동해 결석을 처벌하지 않음.

### B. 크루원 캐릭터와의 상호작용 — 소셜 단계(Phase 3)
- **크루 라운지 입장 시 내 캐릭터가 실제로 등장**, 크루원 캐릭터들이 같은 공간에 함께 존재.
- **완전 실시간 대신 "비동기 프레즌스" 채택:** 크루원 캐릭터는 각자의 마지막 상태(외형·컨디션)를 반영해 라운지에 배치. 인사·하이파이브·이모지 같은 상호작용은 WebSocket으로 가볍게 주고받음.
  - 완전 실시간 멀티플레이(내 동작이 상대 화면에 즉시 반영)는 서버 부담·복잡도가 크므로 초기 범위에서 제외. 필요 시 후속 확장.
- 계획서의 "인터랙티브 크루 라운지"를 이 방식으로 구현 → 감성은 살리고 인프라 부담은 최소화.

### 구현 우선순위
1. **A를 MVP(Phase 2)에 포함** — 홈 상시 렌더링 + 상태 반응. 감성 체감의 80%를 여기서 확보.
2. **B는 Phase 3** — 비동기 프레즌스 + 가벼운 인사/이모지부터. 완전 실시간은 후속 옵션.

---

## 2. 기술 스택 상세

| 레이어 | 선택 | 비고 |
| :--- | :--- | :--- |
| 3D 클라이언트 | Unity 6 LTS + URP | 툰 셰이더, Addressables 원격 배포 |
| UaaL 통합 | flutter_unity_widget 또는 자체 브릿지 | Phase 0에서 안정성 검증 후 확정 |
| 앱 셸 | Flutter 3.x (Dart) | 상태관리 Riverpod, 라우팅 go_router |
| 헬스 연동 | `health` 패키지 or 네이티브 채널 | HealthKit / Health Connect |
| API 서버 | NestJS (TypeScript) | REST + 도메인 모듈화 |
| 실시간 | Socket.IO (별도 게이트웨이) | 크루 라운지, 이모지 반응 |
| DB | MariaDB 11 | 재화 원장, 운동 기록(트랜잭션) |
| 캐시/실시간 | Redis | 세션, 랭킹/피드 캐시, WS pub-sub |
| 오브젝트 스토리지 | S3 + CloudFront | Addressables, 리포트 이미지 |
| 인증 | Sign in with Apple / Google + JWT | 서버 발급 access/refresh |
| 무결성 | App Attest(iOS) / Play Integrity(Android) | 어뷰징 방지 |
| i18n | Flutter `intl` / ARB | 한국어 단일 출시, 구조만 다국어 대비 |
| 결제 | (초기 미적용) | 무과금 — 향후 IAP 확장 시 추가 |
| CI/CD | GitHub Actions + Fastlane | 앱 빌드/배포 자동화 |
| 관측 | Sentry + Grafana/Loki | 크래시·로그·메트릭 |
| IaC | Terraform | 인프라 코드화 |

---

## 3. 팀 구성 (권장 최소 구성)

| 역할 | 인원 | 주 담당 |
| :--- | :--- | :--- |
| Flutter 클라이언트 | 2 | UI 전체, UaaL 브릿지, 헬스 연동 |
| Unity 3D 엔지니어 | 1~2 | 씬/셰이더/에셋 파이프라인/이펙트 |
| 3D 아티스트 (내재화) | 1~2 | 캐릭터·아이템·마이룸 모델링/애니메이션. 아트 스타일가이드·에셋 파이프라인 소유. **Phase 0~1 착수 전 채용 완료 필요** |
| 백엔드 | 2 | API, 재화 원장, 실시간, 어뷰징 검증 |
| 인프라/DevOps | 0.5~1 | 배포, 관측, 부하테스트 (겸임 가능) |
| PM/기획 | 1 | 밸런싱, 시즌 운영, 스토어 대응 |
| QA | 1 (Phase 2부터) | 기기 매트릭스 테스트 |

> 최소 코어는 **Flutter 1 + Unity 1 + 아티스트 1 + 백엔드 1**로 Phase 0~1 진행 가능.

---

## 4. 데이터 모델 (핵심 스키마)

### 4.1 재화 원장 (절대 클라이언트에서 계산 금지)
```
users(id, apple_sub, google_sub, nickname, created_at, ...)

currency_ledger(
  id, user_id, delta, balance_after,
  reason,               -- 'workout_reward' | 'shop_purchase' | 'rest_day' | 'refund'
  ref_type, ref_id,     -- 연관 엔티티 (workout_log / shop_order)
  idempotency_key,      -- 중복 보상 차단 (UNIQUE)
  created_at
)
-- 잔액 = 최신 balance_after. 모든 증감은 트랜잭션으로 원장에 append.
```

### 4.2 운동 기록 & 검증
```
workout_logs(
  id, user_id, sport_type,      -- 'running' | 'weight' | 'walking' ...
  duration_sec, distance_m, calories,
  source,                       -- 'healthkit' | 'health_connect' | 'manual'
  raw_payload_ref,              -- 원본 헬스 데이터(검증용)
  verify_status,                -- 'pending' | 'verified' | 'rejected'
  verified_at, created_at
)

character_stats(user_id, endurance, strength, ..., updated_at)
-- 러닝→지구력, 웨이트→근력 등 종목별 스탯 분화
```

### 4.3 커스터마이징 / 상점
```
items(id, category, rarity, price, addressable_key, has_special_fx, unlock_stat)
inventory(user_id, item_id, acquired_at)      -- 보유
equipped(user_id, slot, item_id)              -- 장착 상태
room_layout(user_id, item_id, x, y, rotation) -- 마이룸 배치
shop_orders(id, user_id, item_id, price, idempotency_key, created_at)
```
> **모든 아이템은 기능 스탯 0.** `has_special_fx`는 시각 효과일 뿐 능력치 없음(계획서 2.2 준수).
> **무과금:** `price`는 오직 운동으로 얻는 인게임 재화 단위. 현금 결제 경로 없음 → `shop_orders`는 재화 원장 차감만 참조. IAP 스키마는 향후 확장 시 별도 추가.

### 4.4 Care System
```
rest_days(user_id, date, rewarded)            -- 공식 휴식일
streaks(user_id, current, longest, protected_until, last_active_date)
streak_protectors(user_id, count)             -- 기록 보호권 보유량
```

### 4.5 소셜 / 크루
```
friendships(user_id, friend_id, status)       -- @nickname 기반
feeds(id, user_id, workout_log_id, message, created_at)
feed_reactions(feed_id, user_id, emoji)       -- 랭킹 없음, 이모지만
crews(id, name, owner_id, goal_type, goal_value)
crew_members(crew_id, user_id, role)
```

### 4.6 캐릭터 상태 & 프레즌스 (살아있는 캐릭터: A/B)
```
-- A. 내 캐릭터 상태 (다마고치형)
character_mood(
  user_id,
  mood,                 -- 'energetic' | 'happy' | 'neutral' | 'hungry' | 'sleepy'
  last_workout_at,      -- 마지막 유효 운동 시각 (mood 산출 기준)
  streak_active,        -- Streak 유지 여부 (신남 상태 트리거)
  updated_at
)
-- mood는 서버가 last_workout_at·streak 등으로 산출(파생값). 클라이언트는 표현만.
-- 부정 상태는 'hungry/sleepy'까지만. 질병/사망 상태 없음(착한 게이미피케이션).

-- B. 크루 라운지 프레즌스 (비동기)
crew_presence(
  crew_id, user_id,
  appearance_snapshot,  -- 장착 아이템 등 외형 스냅샷(라운지 렌더용)
  mood,                 -- 라운지 입장 시점의 상태
  last_seen_at
)
crew_interactions(
  id, crew_id, from_user_id, to_user_id,
  type,                 -- 'wave' | 'highfive' | 'emoji'
  payload, created_at   -- 실시간은 WS로 전달, 로그는 여기 append
)
```

---

## 5. API 설계 (핵심 엔드포인트)

| 도메인 | 엔드포인트 | 설명 |
| :--- | :--- | :--- |
| 인증 | `POST /auth/apple`, `POST /auth/google` | 소셜 로그인 → JWT |
| 운동 | `POST /workouts` | 기록 제출(원본 헬스 데이터 포함) → 검증 큐 |
| 운동 | `GET /workouts?from=&to=` | 기록 조회 |
| 재화 | `GET /wallet` | 잔액 조회(원장 기반) |
| 상점 | `GET /shop/items`, `POST /shop/orders` | 조회/구매(멱등키 필수) |
| 커스텀 | `PUT /character/equip`, `PUT /room/layout` | 장착/배치 |
| Care | `POST /care/rest-day`, `POST /care/use-protector` | 휴식일/보호권 |
| 소셜 | `POST /friends/@:nickname`, `GET /feed` | 친구/피드 |
| 소셜 | `POST /feed/:id/react` | 이모지 반응 |
| 크루 | `POST /crews`, `POST /crews/:id/join` | 크루 |
| 캐릭터(A) | `GET /character/mood` | 홈 상시 렌더용 상태(mood) 조회 |
| 프레즌스(B) | `GET /crews/:id/presence` | 라운지 크루원 캐릭터 외형·상태 스냅샷 |
| 실시간(WS) | `crew:lounge:{id}` 채널 | 라운지 입장/이모지/프레즌스/인사·하이파이브 |
| 리포트 | `GET /reports/monthly/:yyyymm` | 감성 리포트 카드 데이터 |

### 운동 검증 파이프라인 (서버 사이드)
1. `POST /workouts` 수신 → `verify_status=pending`으로 저장
2. Worker가 검증: manual vs OS데이터 대조, 비정상 페이스/심박 이상치 필터, 무결성 토큰 확인
3. `verified` → 재화 원장에 보상 append(멱등키=workout_log_id), 스탯 반영
4. `rejected` → 보상 없음, 사유 로깅

---

## 6. 단계별 스프린트 백로그

> 기간은 코어 팀 기준 예시. 2주 스프린트 단위.

### Phase 0 — 기반 & 리스크 검증 (2~3주) 🔴 최우선
가장 큰 기술 리스크(UaaL·헬스 API)를 먼저 깨는 단계.
- [ ] 모노레포/CI-CD, Flutter·Unity·백엔드 스캐폴딩
- [ ] **UaaL PoC:** Flutter에 Unity 씬 임베드, 양방향 메시지 왕복, iOS/Android 각 실기 빌드
- [ ] **헬스 PoC:** HealthKit·Health Connect에서 걸음 수 수집 → 서버 전송
- [ ] Apple/Google 로그인 + JWT 발급
- [ ] 무결성(App Attest / Play Integrity) 연동 스파이크
- **완료 기준(Exit):** 실기기에서 Flutter↔Unity 통신 + 헬스 1지표 수집 + 로그인 동작

### Phase 1 — 아트 & 3D 프로토타입 (4~6주)
- [ ] 캐릭터 아트 가이드라인 확정, 더미 캐릭터 1종
- [ ] URP 툰 셰이더 확정("따뜻/부드러운" 룩)
- [ ] **표정 텍스처(데칼) 시스템** — 상태별 얼굴 전환용 (A의 기반)
- [ ] 마이룸 기본 씬 + 카메라/터치 인터랙션
- [ ] Addressables 파이프라인 구축(에셋 원격 로드)
- [ ] 아이템 장착 프리뷰(슬롯 1~2종)
- **Exit:** 캐릭터 표시·아이템 장착·마이룸 회전이 앱 안에서 동작

### Phase 2 — MVP (8~10주)
- [ ] 운동 기록 입력 UI(웨이트 타이머/러닝) + 헬스 검증 루프
- [ ] 재화 원장 + 운동 보상 루프(멱등성)
- [ ] 종목별 스탯 분화 + 스탯 연동 아이템 해금
- [ ] 상점 코어(조회→구매→인벤토리→장착)
- [ ] 마이룸 가구 배치 저장/복원
- [ ] Care System 기본형(Rest Day 보상, 기록 보호권)
- [ ] **[A] 살아있는 캐릭터 — 홈 상시 렌더링 + 상태 반응**
  - [ ] `character_mood` 서버 산출(마지막 운동 시각·Streak 기반)
  - [ ] mood별 표정(데칼)·모션·말풍선 매핑, 홈에서 표현
  - [ ] 부정 상태 톤 제한(hungry/sleepy까지, 질병/사망 없음) 검증
- **Exit:** "운동 → 검증 → 재화 → 상점 구매 → 캐릭터 반영" 루프 + 홈에서 내 캐릭터가 상태에 반응

### Phase 3 — 소셜 & 크루 (8~10주, Alpha/Beta)
- [ ] @닉네임 친구 추가/검색
- [ ] 운동 인증 피드 + 이모지 반응(랭킹 없음)
- [ ] 크루 생성/가입, 공동·개인 목표
- [ ] **[B] 크루 라운지 — 내 캐릭터 등장 + 크루원 캐릭터 함께 배치(비동기 프레즌스)**
  - [ ] `crew_presence` 스냅샷(외형·mood) 로드 → 라운지 씬 렌더
  - [ ] 인사·하이파이브·이모지 상호작용(WebSocket)
  - [ ] (후속 옵션) 완전 실시간 동기화는 범위 외로 명시
- [ ] 클로즈드 베타 → 어뷰징 필터 밸런싱, 밸런스 튜닝
- **Exit:** 친구·크루·라운지에 내/크루원 캐릭터가 함께 존재하고 가벼운 상호작용 동작

### Phase 4 — 론칭 & 시즌 운영 (한국 우선)
- [ ] 서버 부하테스트·오토스케일·안정화(국내 리전)
- [ ] 월말 감성 리포트 카드 + SNS 공유 최적화
- [ ] 스토어 심사 대응(헬스 권한 목적 명시, 개인정보 처리방침) — **결제 없음 → 심사 항목 단순**
- [ ] 시즌제 치장 아이템 파이프라인(Addressables 원격 업데이트)
- **Exit:** 국내 정식 출시, 3개월 시즌 운영 로드맵 가동
- **후속(글로벌):** i18n 번역 투입 + 리전 확장. 구조는 이미 잡혀 있으므로 콘텐츠 로컬라이제이션 중심.

---

## 7. 주요 리스크 & 대응

| 리스크 | 영향 | 대응 |
| :--- | :--- | :--- |
| UaaL 임베딩/메모리 안정성 | 높음 | Phase 0 최우선 PoC, Unity 씬 lifecycle 명확화 |
| Android 헬스 API 기기 편차 | 높음 | 삼성/픽셀/샤오미 등 실기 테스트 매트릭스 |
| 스토어 심사(헬스 데이터) | 중 | 최소 수집 원칙, 권한 사유 문서화 선제 준비 |
| 3D 에셋 앱 용량 | 중 | Addressables 원격 다운로드로 초기 번들 경량화 |
| 재화 어뷰징 | 높음 | 서버 원장 + 멱등키 + 무결성 토큰 + 서버 검증 |
| 실시간 라운지 부하 | 중 | Redis pub-sub, WS 게이트웨이 수평 확장 |
| **아트 내재화 병목** | 높음 | Phase 0~1 착수 전 아티스트 채용 완료, 스타일가이드·에셋 파이프라인 조기 확립. 채용 지연 시 초반만 부분 외주로 브릿지 |
| 무과금 수익성 | 중 | 초기엔 리텐션/습관형성 지표 우선. IAP·구독은 지표 확인 후 확장 옵션으로 보류 |

---

## 8. 확정 사항 & 남은 오픈 이슈

**확정됨**
- [x] 과금 모델: **무과금** — 운동 재화만. IAP 초기 배제
- [x] 출시 범위: **한국 우선** — 한국어 단일 로케일, 국내 리전
- [x] 아트: **내재화** — 사내 3D 아티스트

**남은 이슈**
- [ ] 웨어러블 지원 범위(Apple Watch / Galaxy Watch 별도 앱 여부)
- [ ] 시즌당 아이템 물량 산정 및 아티스트 채용 시점 확정(→ Phase 0~1 착수 선행 조건)
- [ ] 무과금 전제하 KPI 정의(리텐션/스트릭 유지율 등) — Phase 3 베타 밸런싱 기준
