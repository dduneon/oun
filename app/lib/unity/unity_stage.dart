import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/global_keys.dart';
import '../shared/widgets/oun_toast.dart';

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
  void _onMessage(String message) {
    debugPrint('Unity → Flutter: $message');
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
  /// Unity 측 OunBridge.LoadScene(string)에서 'home' / 'crew:이름,이름...'을 처리한다.
  void _apply(UnitySceneState s) {
    final arg = switch (s.scene) {
      UnityScene.home => 'home',
      UnityScene.crew => s.payload.isEmpty ? 'crew' : 'crew:${s.payload}',
    };
    sendToUnity('OunBridge', 'LoadScene', arg);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UnitySceneState>(
        unitySceneProvider, (prev, next) => _apply(next));
    final rect = ref.watch(unityViewportProvider);
    final view = EmbedUnity(onMessageFromUnity: _onMessage);
    // rect == null: 전체 화면. rect 지정 시 그 박스에만 렌더(나머지 투명).
    if (rect == null) return view;
    return Stack(children: [Positioned.fromRect(rect: rect, child: view)]);
  }
}
