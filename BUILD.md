# 오운(Oun) 빌드 가이드 — Flutter + Unity (UaaL)

Flutter 앱(`app/`)에 Unity 3D 씬(`unity/`)을 임베드(Unity as a Library)해서 빌드하는 절차.
**일반 `flutter run`으로는 빌드되지 않습니다** — 아래 절차를 따라야 합니다. (이유는 맨 아래 "왜 이렇게 하나" 참고)

- **검증 환경:** macOS(Apple Silicon), Unity 6.5(6000.5.4f1), Flutter 3.44, Xcode 26.5, CocoaPods 1.16
- **패키지:** `flutter_embed_unity` 2.0.0 (+ `_6000_0_android`, `_2022_3_ios`)

---

## 저장소 구조
```
oun/
├── app/        # Flutter 앱
│   └── ios/unityLibrary/   # Unity export 산출물 (gitignore, 재생성 필요)
├── unity/      # Unity 프로젝트 (export 소스)
├── backend/    # 서버 (예정)
└── *.md
```
> `app/ios/unityLibrary/`(약 1.1GB)는 저장소에 없음. 클론 후 아래 Unity export를 다시 실행해야 함.

---

## A. Unity 프로젝트 export

Unity 에디터에서 `unity/`를 연 뒤:

1. **플랫폼 전환:** `File → Build Profiles → iOS → Switch Platform`
2. **스크립팅 백엔드:** `Player Settings → Other Settings → Scripting Backend = IL2CPP`
3. **타겟 아키텍처 (중요):** `Player Settings → Other Settings → Configuration`
   - **실기기:** `Target SDK = Device SDK`
   - **시뮬레이터(Apple Silicon):** `Target SDK = Simulator SDK`, `Simulator architecture = ARM64`
   - ⚠️ 시뮬레이터/실기기 전환 시 매번 이 값을 바꾸고 재export해야 함
4. **씬 빌드 목록:** 홈 캐릭터 씬을 저장하고 `Build Profiles`의 Scene List에 추가(인덱스 0)
5. **EmbedUnity 패키지 임포트** (최초 1회): `Package Manager → + → Install from Git URL`
   ```
   https://github.com/learntoflutter/flutter_embed_unity.git?path=example_unity_6000_0_project/Assets/FlutterEmbed
   ```
6. **export:** `Flutter Embed → Export project to Flutter app → iOS`
   - 대상 폴더: `app/ios/unityLibrary`

---

## B. Flutter / CocoaPods 설정 (최초 1회)

```bash
cd app

# 1) Swift Package Manager 끄기 (SPM은 UnityFramework 링크 실패)
flutter config --no-enable-swift-package-manager
flutter clean && flutter pub get   # ios/Podfile 생성됨
```

`app/ios/Podfile`을 아래처럼 수정:
```ruby
platform :ios, '13.0'              # 주석 해제 (Unity 6 = iOS 13+)
# target 'Runner' do
use_frameworks! :linkage => :static  # 정적 링크 (스텁 프레임워크 심볼 해결)
```

```bash
# 2) pod install — 반드시 UTF-8 로케일로 (아니면 인코딩 에러)
cd ios
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
```

---

## C. Xcode 링크 (최초 1회 / 재export로 풀리면 재확인)

`app/ios/Runner.xcworkspace`를 Xcode로 열고:

1. **Unity 프로젝트 추가:** `File → Add Files to "Runner"` → `app/ios/unityLibrary/Unity-iPhone.xcodeproj`
   (Runner·Pods와 형제 레벨로 워크스페이스에 추가됨)
2. **UnityFramework 임베드:** Runner 타겟 → General → *Frameworks, Libraries, and Embedded Content* → `+` →
   `Workspace → Unity-iPhone → UnityFramework.framework` → **Embed & Sign**
3. **빌드 순서:** Runner 타겟 → Build Phases → `Thin Binary` 단계를 `Embed Frameworks` **아래로** 이동
   (안 하면 `Cycle inside Runner` 에러)

---

## D. 빌드 & 실행 (시뮬레이터)

⚠️ `flutter run` / `flutter build`는 UnityFramework를 빌드하지 않음 → **`xcodebuild` 직접 사용**.

```bash
cd app/ios

# 시뮬레이터 ID 확인
xcrun simctl list devices available | grep -i booted   # 또는 원하는 기기 ID

# 워크스페이스 직접 빌드 (UnityFramework 포함, 최초 수 분 소요)
xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination 'id=<SIMULATOR_ID>' \
  -derivedDataPath build/ios_sim build

# 설치 & 실행
APP=build/ios_sim/Build/Products/Debug-iphonesimulator/Runner.app
xcrun simctl install <SIMULATOR_ID> "$APP"
xcrun simctl launch <SIMULATOR_ID> com.dduneon.oun
open -a Simulator
```

> **실기기 빌드:** Unity를 `Device SDK`로 재export(A-3) 후, `-sdk iphoneos -destination 'id=<DEVICE_ID>'`로 빌드.
> 실기기는 아키텍처 문제가 없어 시뮬레이터보다 오히려 단순함.

---

## E. 푸시(FCM) 설정 — 설정 파일은 커밋되지 않는다

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

---

## F. Android — export · 빌드 · 배포

iOS와 달리 **`flutter build`가 그대로 동작한다.** `unityLibrary`가 gradle 서브프로젝트로 들어가
같이 빌드되므로 `xcodebuild` 같은 우회가 필요 없다.

### F-1. Unity export (에디터 수동 작업)

1. `File → Build Profiles → Android → Switch Platform`
2. `Build Profiles`의 Android 패널에서 **`Export Project` 체크**
   — APK를 굽지 않고 gradle 프로젝트를 내보내게 하는 옵션. 안 켜면 export가 거부된다.
   이 값은 `unity/UserSettings/`(gitignore)에 저장되는 **머신 로컬 설정**이라 클론할 때마다 다시 켜야 한다.
3. `Player Settings → Other Settings`에서 3개:
   - Scripting Backend = **IL2CPP**
   - Application Entry Point = **Activity** (GameActivity는 해제 — 임베드 방식과 호환되지 않는다)
   - Target Architectures = **ARMv7 + ARM64 둘 다** (하나만 켜면 export 체커가 막는다)
4. `Flutter Embed → Export project to Flutter app → Android` → 대상 폴더 **`app/android/unityLibrary`**
5. export 후 Unity 콘솔에 뜨는 `unityStreamingAssets=` 값을 확인.
   기본은 빈 값이라 그대로 두면 되고, StreamingAssets를 쓰기 시작하면
   `app/android/gradle.properties`의 같은 키를 그 값으로 바꾼다.

> `app/android/unityLibrary/`는 gitignore. export 전에는 gradle이
> "android/unityLibrary가 없습니다"라며 멈춘다 — 정상이다.
> **iOS와 export 폴더가 다르니** 플랫폼을 오갈 때마다 Switch Platform + 재export가 필요하다.

gradle 쪽 배선(서브프로젝트 include, `implementation(project(":unityLibrary"))`, NDK r27c,
flatDir, noCompress)은 이미 저장소에 들어가 있다. 추가로 손댈 것 없다.

> **minSdk는 Unity가 정한다.** 앱 gradle은 `minSdk = 26`인데, 이건 Unity의
> `AndroidMinSdkVersion`에 맞춘 값이다(라이브러리 모듈이 앱보다 높으면 AGP가 거부한다).
> Android 6·7 기기까지 받으려면 Unity 쪽 값을 먼저 낮추고 gradle을 따라 낮춰야 한다.

### F-2. 디버그 빌드 / 실기기 확인

**iOS와 달리 에뮬레이터·실기기를 나눠 빌드하지 않는다.** 시뮬레이터 SDK가 따로 있는 iOS와 달리
안드로이드 에뮬레이터는 실기기와 같은 ABI(Apple Silicon 기준 `arm64-v8a`)를 쓰기 때문에
export 하나로 양쪽 다 돈다. 기기를 바꿔 낄 때 재export가 필요 없다 —
**재export가 필요한 건 iOS ↔ Android 플랫폼 전환뿐.**

```bash
cd app
flutter run --dart-define=OUN_API_BASE_URL=http://10.0.2.2:3000
```
> 에뮬레이터에서 호스트의 백엔드는 `localhost`가 아니라 **`10.0.2.2`** 다. 실기기는 PC의 LAN IP.
> 에뮬레이터는 **arm64 이미지 + API 26 이상**이어야 한다. x86_64 이미지를 쓴다면
> Unity에서 Target Architectures에 `x86-64`를 추가로 켜고 재export해야 한다.

배포된 서버를 보게 하려면 그 주소를 넘긴다:
```bash
flutter run --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com
```
> https라 그냥 붙지만, **평문 http 서버로 붙일 때는 막힌다** — Android 9+가 기본 차단하고
> 이 프로젝트의 debug 매니페스트에 `usesCleartextTraffic`이 없다(`10.0.2.2`는 예외로 허용).

### F-3. 릴리스 서명 (최초 1회)

업로드 키를 만들고 `app/android/key.properties`(gitignore)에 경로·비밀번호를 적는다.
양식은 `app/android/key.properties.example` 참고.

```bash
keytool -genkey -v -keystore ~/oun-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`key.properties`가 **없으면 릴리스도 debug 키로 서명된다** — 로컬 확인은 되지만 Play에는 못 올린다.
키를 잃어버리면 같은 앱으로 업데이트가 불가능하니 별도 백업할 것.

### F-4. Play 스토어 업로드

```bash
cd app
flutter build appbundle --release --dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com
```
산출물: `app/build/app/outputs/bundle/release/app-release.aab` → Play Console 내부 테스트 트랙에 업로드.

- 업로드할 때마다 **versionCode를 올려야 한다.** `app/pubspec.yaml`의 `version: 1.0.0+1`에서
  `+` 뒤 숫자를 올리거나, `--build-number=<n>`으로 지정한다.
- APK로 실기기에 바로 꽂아볼 때: `flutter build apk --release` 후
  `adb install -r app/build/app/outputs/flutter-apk/app-release.apk`
- `google-services.json`이 `app/android/app/`에 없으면 **빌드가 실패한다**(E 참고).

### F-5. 버전 충돌이 나면

현재 저장소는 Gradle 9.1 + AGP 9.0.1인데, Unity 6.5가 검증한 조합은 **Gradle 8.13 + AGP 8.10**이다.
`unityLibrary`가 이 조합에서 안 붙으면 다음을 내려서 맞춘다:

| 파일 | 값 |
| :--- | :--- |
| `app/android/gradle/wrapper/gradle-wrapper.properties` | `gradle-8.13-all.zip` |
| `app/android/settings.gradle.kts` | `com.android.application` 버전 `8.10.0` |

---

## 왜 이렇게 하나 (Unity 6.5 + Flutter 3.44 조합에서 겪은 벽)

| 증상 | 원인 | 해결 |
| :--- | :--- | :--- |
| `Undefined symbol: UnityFramework` (SPM) | Flutter 3.44 기본 SPM이 UnityFramework 링크 못 함 | SPM 끄고 CocoaPods |
| 링크 시 `symbol(s) not found for arch` | 스텁 프레임워크가 동적 링크와 안 맞음 | `use_frameworks! :linkage => :static` |
| `not found for architecture arm64/x86_64` | Unity 시뮬레이터 export 아키텍처 불일치 | Simulator architecture = ARM64 재export |
| 빌드가 5초만에 끝나고 링크 실패 | `flutter build`가 UnityFramework 타겟을 안 만듦 | `xcodebuild`로 워크스페이스 직접 빌드 |
| `pod install` 인코딩 에러 | Ruby ASCII-8BIT 로케일 | `LANG/LC_ALL=en_US.UTF-8` |

---

## 상태 (2026-07-18)
- ✅ iOS 시뮬레이터: 홈 화면에 Unity 3D 캐릭터 임베드 동작 확인
- 🔶 Android UaaL: gradle 배선·릴리스 서명은 완료(F), Unity export + 실제 빌드는 미검증
- ⬜ Flutter ↔ Unity 메시지 통신
- ⬜ 배경 투명화(스카이박스 제거)
