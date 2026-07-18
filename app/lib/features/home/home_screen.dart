import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

import '../../theme/app_theme.dart';

/// 캐릭터 무대 홈. Unity(UaaL) 3D 씬을 임베드한다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Flutter → Unity: OunBridge.React() 호출 → 캐릭터 반응
  void _pokeCharacter() {
    sendToUnity('OunBridge', 'React', 'workout');
  }

  void _onUnityMessage(BuildContext context, String message) {
    debugPrint('Unity → Flutter: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('캐릭터 반응: $message'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  '오운',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary,
                  ),
                ),
                Icon(Icons.settings_outlined, color: OunColors.textPrimary),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '오늘의 운동, 나만의 속도로 귀엽게 차곡차곡',
                style: TextStyle(fontSize: 14, color: OunColors.textMuted),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: OunColors.card,
                  child: EmbedUnity(
                    onMessageFromUnity: (msg) => _onUnityMessage(context, msg),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OunColors.seed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _pokeCharacter,
                child: const Text(
                  '오늘 운동 기록하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
