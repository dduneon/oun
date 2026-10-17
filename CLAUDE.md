# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

오운(Oun) is a gamified fitness app: a cute Animal Crossing–style character that lives on the home screen and reacts to the user's workouts. Emotional/encouragement-first (no rankings), non-monetized (workout-earned currency only), Korean-first launch, iOS + Android.

The product/planning source of truth is `service_development_plan_oun.md` (spec) and `development_plan_oun.md` (execution plan, decisions, data models). Read these before making product decisions — many things (no stats on shop items, "no punish for rest days", currency computed server-side only) are deliberate constraints, not omissions. Note those docs predate the switch from an embedded Unity 3D character to pre-rendered 2D layers.

## Monorepo layout

```
oun/
├── app/       Flutter app (all UI, including the character)
├── backend/   NestJS + Prisma API (implemented — see "Backend")
├── art/       Character layer source: art/character/oun_villager.blend + render_layers.py
├── unity/     Legacy Unity project — no longer used by the app
└── BUILD.md   Build/deploy runbook (FCM files, signing, TestFlight, character assets)
```

The character used to be a Unity 3D scene embedded via UaaL. It is now **2D layer PNGs rendered offline from Blender** and composited in Flutter — there is no 3D engine in the app. `unity/` is left in the repo but nothing builds or references it. **Server/state is always the source of truth; the character only displays.**

## Building & running

Plain Flutter — `flutter run` / `flutter build` work on both iOS and Android (from `app/`):
```bash
flutter run --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com
flutter build ios --simulator --debug --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com
flutter analyze
flutter test
```
- Always pass `--dart-define=OUN_API_BASE_URL=...`; without it the app talks to `http://localhost:3000`, session restore fails, and the user gets logged out.
- Simulator install loop: `xcrun simctl install <SIM_ID> build/ios/iphonesimulator/Runner.app && xcrun simctl launch <SIM_ID> com.dduneon.oun` (`xcrun simctl list devices available | grep Booted` for the id). If it shows a stale tab, `simctl terminate` then `launch` again.
- iOS uses CocoaPods with Swift Package Manager **off** and `use_frameworks! :linkage => :static`. These were originally for UnityFramework; Firebase now comes in via CocoaPods, so don't flip them without re-verifying the iOS build and push.
- `pod install` needs a UTF-8 locale: `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install`.
- Release signing on Android reads `app/android/key.properties` (gitignored) and silently falls back to the debug key when absent. Firebase config files are gitignored too — see `BUILD.md`.

### Changing the character art
Layers come from `art/character/oun_villager.blend` (one collection per layer), rendered with the same orthographic camera onto an 800×1000 canvas by `art/character/render_layers.py` into `app/assets/character/`:
```bash
blender art/character/oun_villager.blend --background --python art/character/render_layers.py
```
- Occluded parts are cut out at render time by rendering BODY as a holdout, so layers just stack in Flutter.
- If you change the body shape, re-render **all** layers or they stop lining up.
- **Hair is currently not drawn.** `CharacterLook` has no hair layer and `app/assets/character/` has no `hair_*.png`; `render_layers.py` still renders hair collections, but those outputs aren't shipped. Shop hair items can still be bought/equipped but don't show on the character.

## Flutter architecture (`app/lib`)

- **Routing:** `go_router` `StatefulShellRoute.indexedStack` in `router.dart` — 5 bottom tabs (홈/기록/상점/소셜/마이). IndexedStack keeps every tab alive across switches.
- **State:** Riverpod (`ProviderScope` in `main.dart`). Screen data comes from the backend via `FutureProvider`s in `shared/api/providers.dart`; an auth gate (`authProvider`) shows login/splash over the router until a session is restored (`app.dart`).
- **Structure:** feature-first — `features/{auth,home,record,shop,crew,my,character}/` (the 소셜 tab lives in `features/crew/`), shared pieces in `shared/widgets/`, API layer in `shared/api/`, design tokens in `theme/app_theme.dart` (`OunColors` + `AppTheme`).
- **Design system:** warm palette in `OunColors`. Background `#FDF6F0`, soft cards `#F3E9DF`, list surfaces `#FFFDFB`, terracotta tab accent `#C47A45`.
- **Bottom nav:** custom `FloatingTabBar` (floating frosted capsule, selected tab expands with a label) — not Material `NavigationBar`. `MainScaffold` uses `extendBody: true`; screens reserve `FloatingTabBar.reservedSpace` (+ safe area) at the bottom so content clears the floating bar. `PageScaffold` handles this for the non-home tabs.
- **Home** is character-first: minimal header (greeting/coins), the character on a stage, and one frosted card with today's stats + CTA.

## Character (`features/character/character_avatar.dart`)

- `CharacterLook(gender, equipment)` decides which layer PNGs to stack from the server's equipped items (slot → item key): `body*` (face expression variants baked into the body layer) → top → towel → earbuds/cap. Unknown keys fall back to `top_basic` / no prop. `gender` (`m`/`f`, chosen at signup) currently doesn't change the look since hair isn't drawn.
- `CharacterFigure` draws one static character (layers + ground shadow); `LivingCharacter` adds breathing, occasional blinks (swaps to `body_blink`), and a hop + `body_happy` on tap.
- Reactions: `characterReactionProvider.notifier.play()` triggers a hop on the home character (`LivingCharacter(reactToProvider: true)`). Home uses it for workout pokes and unseen cheers.
- Used on home (`home_screen.dart`), crew gathering (`crew_home.dart`, one per member by `gender`), and friend home (`friend_home_screen.dart`).

## Backend (`backend/`, NestJS + Prisma)

Fully implemented API. MariaDB (Prisma `mysql` provider), Redis (reserved), and MinIO (object storage) run via `backend/docker-compose.yml`.

**Local loop** (from `backend/`):
```bash
docker compose up -d                 # mariadb :3306, redis :6379, minio :9000 (console :9001)
npm run prisma:migrate               # apply migrations (dev)
npm run prisma:seed                  # demo users: jimin, hyunwoo, seoyeon (+ achievements)
npm run start:dev                    # nest watch on :3000
npm test                             # unit (jest)
npm run test:e2e                     # e2e — needs docker infra + seed; runs serially (--runInBand)
npx jest --config test/jest-e2e.json <name>   # a single e2e suite (e.g. "auth", "social", "mutations")
```
- **Migrations in a non-interactive shell:** `prisma migrate dev` prompts and fails here. Write the migration folder + `migration.sql` by hand, then `npx prisma migrate deploy && npx prisma generate`.
- e2e specs (`backend/test/*.e2e-spec.ts`) hit the **real** dev DB + MinIO; they use `/auth/dev` to mint users quickly and a looser ValidationPipe (`whitelist` only) than the app.

**Non-obvious architecture** (read across modules to grasp):
- **Money is an append-only ledger.** All coin changes go through `LedgerService.append(tx, {delta, reason, idempotencyKey, refType, refId})` → `CurrencyLedger`. Balance = latest `balanceAfter`; **never compute currency on the client** (a deliberate product constraint). Idempotency key blocks double-credit. Reversals are `reason: 'refund'` rows; workout **edit/delete reconcile coins by summing all ledger rows for that workout** (refType `workout_log`, refId), not by touching the original entry.
- **Auth = JWT access+refresh, three entry paths.** `/auth/register` + `/auth/login` (username/password, bcrypt) are the real accounts; `/auth/dev` is a nickname find-or-create stub (blocked when `NODE_ENV=production`, used by e2e and the app's `mode: signup|login` variants historically); `/auth/kakao` verifies a Kakao token. `/auth/refresh` rotates tokens. Guarded routes use `JwtAuthGuard` + the `@CurrentUser()` `AuthUser` decorator (`common/`). The app persists only the **refresh token** and auto-refreshes on 401.
- **Domain transactions compose via `tx`.** Services take a `Prisma.TransactionClient` so higher-level flows stay atomic. `workouts.create` applies reward + stats/streak/mood (`GameService.applyWorkout`) + quests + achievements in one transaction; `verifyWorkout` (`workouts/verify.ts`) auto-approves manual logs minus outliers (impossible pace/steps). **Workout edit/delete reconcile coins but intentionally do NOT recompute stats/streak/quests.**
- **Crews:** one `Crew` + `CrewMember` (role `leader|member`); feed `CrewPost` optionally tags a workout (its photo). Joining is via **requests** (discover public crews → request → leader approves) or **invites** (leader invites → user accepts) — both unified in `CrewJoinRequest` (`type: request|invite`). Leader-only actions checked via `leaderOf`.
- **Friends** are symmetric two-row `Friendship`; adding is request→accept (`FriendRequest`), auto-accepting a reciprocal pending request.
- **Storage:** `StorageService` (MinIO) issues **presigned PUT** URLs (`POST /uploads/workout-photo`) so the app uploads directly; the bucket is public-read and read endpoints return a `photoUrl`.
- **Time:** KST day/week boundaries live in `common/time.ts` (used for streaks, weekly counts, calendar).

**App ↔ backend wiring:** base URL is `--dart-define=OUN_API_BASE_URL` (default `http://localhost:3000`; Android emulator needs `http://10.0.2.2:3000`; the deployed server is `https://oun-api.dduneon.com`). `ApiClient` (`app/lib/shared/api/api_client.dart`) attaches the access token and retries once via `/auth/refresh` on 401. Riverpod `FutureProvider`s in `providers.dart` are the app's read layer; mutations call `apiClientProvider` then `ref.invalidate(...)` the relevant provider.

## Conventions

- UI copy and comments are Korean. Commit messages: conventional-commit prefix, Korean body, one logical unit per commit (`feat(app):`, `chore(art):`, `fix:` …).
- After changing character art, re-render the layers and check them composited (or in the app) — the PNGs, not the blend, are what ships.
