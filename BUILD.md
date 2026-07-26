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
- ⬜ Android UaaL 연동 (동일 패턴: 플랫폼 전환 → export → gradle 링크)
- ⬜ Flutter ↔ Unity 메시지 통신
- ⬜ 배경 투명화(스카이박스 제거)
