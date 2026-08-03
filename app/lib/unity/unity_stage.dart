import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/api/providers.dart';
import '../shared/global_keys.dart';
import '../shared/widgets/oun_toast.dart';
import '../theme/app_theme.dart';

/// Unity가 보여줄 씬. 엔진은 하나뿐이라 씬을 전환하며 재사용한다.
enum UnityScene { home, crew }

class UnitySceneState {
  const UnitySceneState(this.scene, [this.payload = '']);
  final UnityScene scene;
  final String payload; // 크루 씬일 때 멤버 등 부가 정보

  @override
  bool operator ==(Object other) =>
      other is UnitySceneState &&
      other.scene == scene &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(scene, payload);
}

/// 현재 Unity 씬 상태. 화면들이 이걸 바꾸면 UnityHost가 Unity에 전환 메시지를 보낸다.
class UnitySceneController extends Notifier<UnitySceneState> {
  @override
  UnitySceneState build() => const UnitySceneState(UnityScene.home);

  void showHome() => state = const UnitySceneState(UnityScene.home);
  void showCrew(String payload) =>
      state = UnitySceneState(UnityScene.crew, payload);
}

final unitySceneProvider =
    NotifierProvider<UnitySceneController, UnitySceneState>(
        UnitySceneController.new);

/// Unity 홈 씬이 "처음" 준비됐는지. 앱 첫 로딩 화면을 언제 걷을지 판단하는 신호다.
/// 엔진 로드 + 씬 로드 + 캐릭터 스폰까지 몇 초 걸리는데, 그동안 Unity가 자체
/// 스플래시와 빈 화면을 보여주므로 오운 로딩 화면으로 덮는다.
class UnityBootController extends Notifier<bool> {
  @override
  bool build() => false;

  void markReady() {
    if (!state) state = true;
  }
}

final unityBootedProvider =
    NotifierProvider<UnityBootController, bool>(UnityBootController.new);

/// Unity 뷰가 차지할 화면 영역. null이면 전체 화면(홈), 사각형이면 그 박스에만
/// 렌더(크루 무대처럼 일부 영역에 딱 맞춤).
class UnityViewportController extends Notifier<Rect?> {
  @override
  Rect? build() => null;

  void setRect(Rect? r) => state = r;
}

final unityViewportProvider =
    NotifierProvider<UnityViewportController, Rect?>(
        UnityViewportController.new);

/// 앱 전역에 단 하나 존재하는 Unity 뷰.
///
/// 재마운트하지 않고(= "한 번만 로드" 규칙 유지) 씬만 메시지로 전환한다.
/// 앱 최상위(Stack의 맨 뒤)에 깔리며, 홈·크루 광장처럼 투명한 라우트에서만
/// 비쳐 보이고 나머지 불투명 화면 뒤에서는 가려진다.
class UnityHost extends ConsumerStatefulWidget {
  const UnityHost({super.key});

  @override
  ConsumerState<UnityHost> createState() => _UnityHostState();
}

class _UnityHostState extends ConsumerState<UnityHost> {
  // 씬 전환 진행 중(LoadScene을 보냈고 아직 *_ready를 못 받음)이면 Unity 뷰 위를
  // 불투명하게 가린다. Unity 같은 네이티브 플랫폼 뷰는 씬/카메라 전환·리사이즈
  // 순간(줌·검은 프레임)이 Flutter 위젯으로 가려도 삐져나오므로, Unity 뷰와 같은
  // 서브트리에서 바로 위를 덮어 원천적으로 가린다.
  bool _busy = false;
  Timer? _busyTimeout; // *_ready가 안 오는 최악의 경우 대비 안전 해제.
  Timer? _bootTimeout; // 첫 로딩 화면이 영원히 안 걷히는 것 방지.

  @override
  void initState() {
    super.initState();
    // Unity가 끝내 준비 신호를 못 보내도(엔진 실패 등) 사용자를 로딩 화면에
    // 가둬두지 않는다. 첫 로드는 기기에 따라 수 초 걸리므로 넉넉히 잡는다.
    _bootTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted) ref.read(unityBootedProvider.notifier).markReady();
    });
  }

  @override
  void dispose() {
    _busyTimeout?.cancel();
    _bootTimeout?.cancel();
    super.dispose();
  }

  void _setBusy(bool v) {
    _busyTimeout?.cancel();
    if (v) {
      // 준비 완료 신호가 유실돼도 영구히 가려지지 않도록 안전장치.
      _busyTimeout = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _busy) setState(() => _busy = false);
      });
    }
    if (mounted && _busy != v) setState(() => _busy = v);
  }

  void _onMessage(String message) {
    debugPrint('Unity → Flutter: $message');
    // 씬 로드 완료 → 가림막 해제.
    if (message == 'crew_ready' || message == 'home_ready') {
      _setBusy(false);
      // 캐릭터가 실제로 화면에 선 시점 = 첫 로딩 화면을 걷을 시점.
      if (message == 'home_ready') {
        _bootTimeout?.cancel();
        ref.read(unityBootedProvider.notifier).markReady();
      }
      return;
    }
    // Unity 엔진 준비 완료 → 현재 씬을 (사용자 토큰 포함해) 최초 1회 전송.
    // 엔진 로드 전에 보낸 메시지는 유실되므로 이 신호를 받고 나서 스폰을 시작한다.
    if (message == 'unity_ready') {
      _apply(ref.read(unitySceneProvider));
      return;
    }
    // 캐릭터 반응(react) → 전역 메신저로 토스트
    if (message.startsWith('reacted')) {
      final messenger = rootMessengerKey.currentState;
      if (messenger != null) {
        OunToast.showWith(
          messenger,
          '오운이가 반응했어요!',
          kind: OunToastKind.cheer,
          icon: Icons.pets_rounded,
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  /// 씬 상태 변화를 Unity로 보낸다.
  /// Unity 측 OunBridge.LoadScene(string)에서 'home:토큰' / 'crew:토큰,...'을 처리한다.
  void _apply(UnitySceneState s) {
    // 씬/카메라가 바뀌는 순간이 보이지 않도록, 준비 완료(*_ready)까지 가린다.
    _setBusy(true);
    final arg = switch (s.scene) {
      // 홈도 크루처럼 사용자 본인 아바타 토큰으로 스폰 → 홈↔크루 캐릭터 일치.
      UnityScene.home => 'home:${_homeToken()}',
      UnityScene.crew => s.payload.isEmpty ? 'crew' : 'crew:${s.payload}',
    };
    sendToUnity('OunBridge', 'LoadScene', arg);
  }

  /// 현재 사용자 본인의 캐릭터 토큰('m'/'f'). 크루원 charToken과 같은 규칙.
  /// 프로필이 아직 없으면 여성 폴백(로드되면 리스너가 다시 보낸다).
  String _homeToken() =>
      ref.read(authProvider).profile?.gender == 'm' ? 'm' : 'f';

  @override
  Widget build(BuildContext context) {
    ref.listen<UnitySceneState>(
        unitySceneProvider, (prev, next) => _apply(next));
    // 프로필(성별)이 로드/변경되면 홈 씬일 때 아바타를 다시 스폰한다.
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.profile?.gender != next.profile?.gender &&
          ref.read(unitySceneProvider).scene == UnityScene.home) {
        _apply(ref.read(unitySceneProvider));
      }
    });
    final rect = ref.watch(unityViewportProvider);
    final view = EmbedUnity(onMessageFromUnity: _onMessage);
    // 씬 전환 중 Unity 뷰 바로 위를 덮는 가림막(전환 중 즉시 불투명, 완료 후 페이드).
    final cover = IgnorePointer(
      child: AnimatedOpacity(
        opacity: _busy ? 1 : 0,
        duration:
            _busy ? Duration.zero : const Duration(milliseconds: 180),
        child: const ColoredBox(color: OunColors.background),
      ),
    );
    // rect == null: 전체 화면. rect 지정 시 그 박스에만 렌더(나머지 투명).
    if (rect == null) {
      return Stack(children: [
        Positioned.fill(child: view),
        Positioned.fill(child: cover),
      ]);
    }
    return Stack(children: [
      Positioned.fromRect(rect: rect, child: view),
      Positioned.fromRect(rect: rect, child: cover),
    ]);
  }
}
