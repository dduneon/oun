# 오운(Oun) 빌드 가이드 — Flutter

앱(`app/`)은 순수 Flutter 앱이다. 예전에는 Unity 3D 씬을 임베드(UaaL)해서 `xcodebuild`로만
빌드됐지만, 캐릭터를 미리 렌더한 2D 레이어 PNG로 바꾸면서 Unity 의존성을 걷어냈다.
**이제 `flutter run` / `flutter build`가 iOS·Android 모두 그대로 동작한다.**

- **검증 환경:** macOS(Apple Silicon), Flutter 3.44, Xcode 26.5, CocoaPods 1.16

---

## 저장소 구조
```
oun/
├── app/        # Flutter 앱
├── backend/    # NestJS + Prisma API
├── art/        # 캐릭터 레이어 원본(blend)과 렌더 스크립트 — D 참고
├── unity/      # 예전 Unity 프로젝트. 앱은 더 이상 쓰지 않는다
└── *.md
```
> 예전 export 산출물 `app/ios/unityLibrary/`·`app/android/unityLibrary/`(gitignore, 약 1GB)가
> 로컬에 남아 있다면 지워도 된다. 빌드에서 참조하지 않는다.

---

## A. 최초 설정

```bash
cd app
flutter pub get

# CocoaPods는 UTF-8 로케일로 (아니면 인코딩 에러)
cd ios
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
```

- Swift Package Manager는 꺼져 있고(`flutter config --no-enable-swift-package-manager`)
  CocoaPods `use_frameworks! :linkage => :static`을 쓴다. 원래 UnityFramework 링크 때문에 넣은
  설정이지만, Firebase 네이티브 SDK가 CocoaPods로 들어오는 구성이라 그대로 둔다.
  바꾸려면 iOS 빌드·푸시를 다시 검증한 뒤에 바꾼다.
- 푸시(FCM) 설정 파일은 저장소에 없다 — C 참고.

---

## B. 빌드 & 실행

### iOS 시뮬레이터

```bash
cd app
flutter run --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com
```

`flutter run` 대신 빌드만 해서 설치할 때:
```bash
flutter build ios --simulator --debug --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com
xcrun simctl install <SIMULATOR_ID> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <SIMULATOR_ID> com.dduneon.oun
```
- 시뮬레이터 ID: `xcrun simctl list devices available | grep Booted`
- `--dart-define=OUN_API_BASE_URL`을 빼면 `http://localhost:3000`을 본다.
  로컬 백엔드를 띄운 게 아니면 세션 복원이 실패해 로그아웃된다.
- 다시 설치한 뒤 예전 탭이 보이면 `simctl terminate` 후 다시 `launch`한다(상태가 복원될 수 있다).

### Android

```bash
cd app
flutter run --dart-define=OUN_API_BASE_URL=http://10.0.2.2:3000
```
> 에뮬레이터에서 호스트의 백엔드는 `localhost`가 아니라 **`10.0.2.2`** 다. 실기기는 PC의 LAN IP.
> 배포 서버는 `https://oun-api.dduneon.com`을 넘긴다. **평문 http 서버는 막힌다** —
> Android 9+가 기본 차단하고 debug 매니페스트에 `usesCleartextTraffic`이 없다(`10.0.2.2`는 예외).

- `minSdk`는 23이다(`flutter_secure_storage`의 EncryptedSharedPreferences 요구).
- NDK는 28.2(Flutter 플러그인 요구).

### 빠른 확인

```bash
cd app
flutter analyze
flutter test
```

---

## C. 푸시(FCM) 설정 — 설정 파일은 커밋되지 않는다

공개 저장소라 Firebase 설정 파일 2개는 **gitignore**되어 있다. 클론 후 직접 배치해야 한다.

| 파일 | 위치 | 없으면 |
| :--- | :--- | :--- |
| `GoogleService-Info.plist` | `app/ios/Runner/` | iOS 푸시만 비활성(앱은 정상 동작) |
| `google-services.json` | `app/android/app/` | **Android 빌드 실패** (google-services 플러그인이 요구) |

Firebase 콘솔 → 프로젝트 설정 → 내 앱에서 받는다. 두 앱 모두 ID는 `com.dduneon.oun`.

- iOS는 파일을 두는 것만으로 부족하고 **Runner 타깃의 Resources 빌드 단계**에 들어가야 한다
  (이미 `project.pbxproj`에 등록돼 있어 같은 경로에 두면 그대로 잡힌다).
- Firebase 콘솔이 안내하는 **"SDK 추가(SPM)" · "초기화 코드 추가" 단계는 건너뛴다.**
  네이티브 SDK는 CocoaPods로 이미 들어오고(`firebase_core`/`firebase_messaging`),
  초기화는 Dart 쪽 `firebase_core`가 한다. SPM으로 또 추가하면 심볼이 중복돼 링크가 깨진다.
- 서버 전송에는 별도로 `backend/.env`의 `FIREBASE_SERVICE_ACCOUNT`(서비스 계정 JSON)가 필요하다.
  **이건 진짜 비밀키다 — 절대 커밋 금지.** 없으면 푸시만 no-op이고 인앱 알림함은 정상 동작한다.
- 실기기 푸시에는 Xcode의 **Push Notifications capability**(`Runner.entitlements`)와
  Firebase에 업로드한 **APNs 인증 키(.p8)** 가 필요하다. 시뮬레이터는 토큰이 잡히지 않는 게 정상.
- 엔타이틀먼트는 설정별로 다르다: Debug/Profile은 `Runner/Runner.entitlements`(`aps-environment
  = development`), **Release는 `Runner/RunnerRelease.entitlements`(`production`)**.
  TestFlight 빌드는 프로덕션 APNs를 쓰므로 development로 올리면 토큰이 샌드박스라 푸시가 안 온다.

---

## D. 캐릭터 레이어 에셋

홈·크루·친구 홈의 캐릭터는 3D 엔진 없이 **같은 카메라·같은 캔버스(800×1000)로 미리 렌더한
레이어 PNG**를 겹쳐 그린다(`app/lib/features/character/character_avatar.dart`).

- 원본: `art/character/oun_villager.blend` (컬렉션 하나 = 레이어 하나)
- 렌더 스크립트: `art/character/render_layers.py` → `app/assets/character/*.png`
  ```bash
  blender art/character/oun_villager.blend --background --python art/character/render_layers.py
  ```
- 겹치는 순서: 몸(`body*.png`, 표정 3종) → 상의 → 타월 → 이어폰·모자.
  가려져야 하는 부분은 렌더할 때 BODY를 홀드아웃으로 미리 뚫어 둔다.
- **머리카락 레이어는 현재 앱에서 그리지 않는다.** `render_layers.py`는 아직 `hair_*` 레이어도
  렌더하지만 그 PNG는 `app/assets/character/`에 두지 않는다.
- 레이어 하나만 다시 렌더해도 되지만, **몸 모양을 바꿨다면 전 레이어를 다시 렌더**해야 맞물린다.
- PNG만 바뀌면 앱 코드는 그대로다. 새 아이템을 추가할 때만 `CharacterLook`의 키 목록을 늘린다.

---

## E. Android 배포

### E-1. 릴리스 서명 (최초 1회)

업로드 키를 만들고 `app/android/key.properties`(gitignore)에 경로·비밀번호를 적는다.
양식은 `app/android/key.properties.example` 참고.

```bash
keytool -genkey -v -keystore ~/oun-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`key.properties`가 **없으면 릴리스도 debug 키로 서명된다** — 로컬 확인은 되지만 Play에는 못 올린다.
키를 잃어버리면 같은 앱으로 업데이트가 불가능하니 별도 백업할 것.

### E-2. Play 스토어 업로드

```bash
cd app
flutter build appbundle --release --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com
```
산출물: `app/build/app/outputs/bundle/release/app-release.aab` → Play Console 내부 테스트 트랙에 업로드.

- 업로드할 때마다 **versionCode를 올려야 한다.** `app/pubspec.yaml`의 `version: 1.0.0+1`에서
  `+` 뒤 숫자를 올리거나, `--build-number=<n>`으로 지정한다.
- APK로 실기기에 바로 꽂아볼 때: `flutter build apk --release` 후
  `adb install -r app/build/app/outputs/flutter-apk/app-release.apk`
- `google-services.json`이 `app/android/app/`에 없으면 **빌드가 실패한다**(C 참고).

---

## F. iOS 배포 — TestFlight

### F-1. 준비

1. **버전 올리기:** `app/pubspec.yaml`의 `version: <이름>+<빌드번호>`.
   TestFlight는 **같은 빌드번호를 두 번 받지 않는다** — 올릴 때마다 `+` 뒤를 올린다.
2. 필요하면 `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install`(A 참고).

### F-2. ipa 만들기

```bash
cd app
flutter build ipa --release \
  --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com \
  --export-options-plist=ios/ExportOptions.plist
```
산출물: `app/build/ios/ipa/*.ipa`. 서명은 자동(팀 `A4YL85FB4L`).
`ios/ExportOptions.plist`는 gitignore라 없으면 Xcode에서 한 번 export해서 만든다.

`flutter build ipa`가 서명·프로비저닝에서 막히면 `xcodebuild`로 직접 아카이브한다.
이때는 **먼저 `flutter build ios --release --config-only --dart-define=...`로
`ios/Flutter/Generated.xcconfig`를 갱신해야 한다** — 버전·`--dart-define`은 이 파일로만
xcodebuild에 전달된다. 빼먹으면 예전 버전 번호와 예전 API 주소(기본값 localhost)로 빌드된다.
```bash
cd app/ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -archivePath build/Runner.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Runner.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/ipa -allowProvisioningUpdates
```

### F-3. 업로드

| 방법 | 명령/도구 |
| :--- | :--- |
| Transporter 앱 | ipa를 끌어다 놓기(가장 단순) |
| App Store Connect API 키 | `xcrun altool --upload-app -f <ipa> -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>` |
| 앱 암호 | `xcrun altool --upload-app -f <ipa> -t ios -u <Apple ID> -p <app-specific password>` |

> 업로드 전에 검증만 해보려면 `--validate-app`으로 같은 명령을 한 번 돌린다.
> 처리(Processing)에 10~30분. 수출 규정(암호화) 문항은 `Info.plist`의
> `ITSAppUsesNonExemptEncryption = false`로 이미 답해 둬서 매번 묻지 않는다.

### F-4. 자주 걸리는 것

| 증상 | 원인 | 해결 |
| :--- | :--- | :--- |
| 올린 빌드가 옛 버전/옛 API 주소 | `--dart-define` 누락, 또는 xcodebuild 경로에서 `Generated.xcconfig` 미갱신 | F-2의 `--config-only` 실행 후 재빌드 |
| `ITMS-90189` 중복 빌드번호 | 같은 빌드번호 재업로드 | `pubspec.yaml`의 `+n` 올리기 |
| TestFlight에서 푸시 안 옴 | `aps-environment`가 development | Release는 `RunnerRelease.entitlements`(C 참고) |
| 프로파일에 Push capability 없음 | 자동 서명 갱신 안 됨 | `-allowProvisioningUpdates` 유지, ADC에서 App ID 확인 |
| `pod install` 인코딩 에러 | Ruby ASCII-8BIT 로케일 | `LANG/LC_ALL=en_US.UTF-8` |

---

## 상태 (2026-10-17)
- ✅ iOS 시뮬레이터: `flutter build ios --simulator`로 빌드, 2D 레이어 캐릭터 동작 확인
- 🔶 Unity를 걷어낸 뒤 Android 빌드, iOS 아카이브·TestFlight 업로드는 아직 다시 확인하지 않았다
