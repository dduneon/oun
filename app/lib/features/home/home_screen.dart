import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

import '../../shared/widgets/floating_tab_bar.dart';
import '../../theme/app_theme.dart';

/// 캐릭터 우선 홈. Unity 3D 씬이 화면 전체(풀블리드)를 채우고,
/// 인사·상태·CTA 등 UI가 그 위에 떠 있다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _pokeCharacter() => sendToUnity('OunBridge', 'React', 'workout');

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
    return Stack(
      children: [
        // 풀블리드 캐릭터
        Positioned.fill(
          child: EmbedUnity(
            onMessageFromUnity: (m) => _onUnityMessage(context, m),
          ),
        ),
        // 그 위에 떠 있는 UI
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                _TopRow(),
                const SizedBox(height: 12),
                const _StatChips(),
                // 말풍선 위치. 위 Spacer가 작을수록 위로 올라감
                const Spacer(flex: 1),
                const _SpeechBubble('오늘도 같이 힘내볼까요?'),
                const Spacer(flex: 11),
                _Cta(onTap: _pokeCharacter),
                // 플로팅 탭바(+안전영역) 위로 CTA가 올라오도록 여백 확보
                SizedBox(
                  height: MediaQuery.viewPaddingOf(context).bottom +
                      FloatingTabBar.reservedSpace,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('좋은 아침이에요',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: OunColors.textPrimary)),
              SizedBox(height: 2),
              Text('오늘도 나만의 속도로',
                  style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
            ],
          ),
        ),
        const _CurrencyChip(amount: 1240),
      ],
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.paid_rounded, size: 15, color: Color(0xFFE0A94B)),
          const SizedBox(width: 5),
          Text('$amount',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
        ],
      ),
    );
  }
}

class _StatChips extends StatelessWidget {
  const _StatChips();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatChip(value: '12일', label: '연속 기록')),
        SizedBox(width: 7),
        Expanded(child: _StatChip(value: '32분', label: '오늘 운동')),
        SizedBox(width: 7),
        Expanded(child: _StatChip(value: 'Lv.7', label: '지구력')),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
          const SizedBox(height: 1),
          Text(label,
              style: const TextStyle(fontSize: 10, color: OunColors.textMuted)),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: OunColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OunColors.cardBorder),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: OunColors.textPrimary)),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: OunColors.card,
                border: Border(
                  right: BorderSide(color: OunColors.cardBorder),
                  bottom: BorderSide(color: OunColors.cardBorder),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: OunColors.seed,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: onTap,
        child: const Text('오늘 운동 기록하기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
