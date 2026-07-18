import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/floating_tab_bar.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 캐릭터 우선 홈(A안 · 차분한 무대).
/// 상단은 인사·코인으로 최소화해 3D 캐릭터에 무대를 내주고,
/// 하단 프로스티드 카드 하나에 오늘의 스탯 + CTA를 모은다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _pokeCharacter() => sendToUnity('OunBridge', 'React', 'workout');

  void _onUnityMessage(BuildContext context, String message) {
    debugPrint('Unity → Flutter: $message');
    OunToast.show(
      context,
      '오운이가 반응했어요!',
      kind: OunToastKind.cheer,
      icon: Icons.pets_rounded,
      duration: const Duration(seconds: 1),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return '늦은 밤이에요';
    if (h < 12) return '좋은 아침이에요';
    if (h < 18) return '좋은 오후예요';
    return '좋은 저녁이에요';
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
        // 하단 그라데이션 스크림: 캐릭터 하반신이 배경 바닥으로 부드럽게
        // 녹아들도록 해, 카드에 다리가 딱 잘리는 느낌을 없앤다.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 300,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    OunColors.background,
                    OunColors.background.withValues(alpha: 0.0),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        // 그 위에 떠 있는 UI
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                _TopRow(greeting: _greeting()),
                const Spacer(),
                _TodayCard(
                  onRecord: () => context.go('/record'),
                  onPoke: _pokeCharacter,
                ),
                // 플로팅 탭바(+안전영역) 위로 카드가 올라오도록 여백 확보.
                // +22: 카드와 탭바 사이 숨 쉴 간격을 조금 더 준다.
                SizedBox(
                  height: MediaQuery.viewPaddingOf(context).bottom +
                      FloatingTabBar.reservedSpace +
                      22,
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
  const _TopRow({required this.greeting});
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: OunColors.textPrimary,
                      letterSpacing: -0.2)),
              const SizedBox(height: 2),
              const Text('오늘도 나만의 속도로',
                  style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
            ],
          ),
        ),
        const _CoinPill(amount: '1,240'),
      ],
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.amount});
  final String amount;

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
          const Icon(Icons.paid_rounded, size: 15, color: OunColors.coin),
          const SizedBox(width: 5),
          Text(amount,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
        ],
      ),
    );
  }
}

/// 하단 프로스티드 카드: 오늘 스탯 3종 + 기록 CTA.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.onRecord, required this.onPoke});
  final VoidCallback onRecord;
  final VoidCallback onPoke;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OunColors.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: OunColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: OunColors.textPrimary.withValues(alpha: 0.12),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(child: _Stat(value: '12일', label: '연속 기록')),
                  _StatDivider(),
                  Expanded(child: _Stat(value: '32분', label: '오늘 운동')),
                  _StatDivider(),
                  Expanded(child: _Stat(value: 'Lv.7', label: '지구력')),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: OunColors.tabAccent,
                        foregroundColor: OunColors.onTabAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: onRecord,
                      child: const Text('오늘 운동 기록하기',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 9),
                  // 캐릭터 쓰다듬기(부가 상호작용)
                  Material(
                    color: OunColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: OunColors.cardBorder),
                    ),
                    child: InkWell(
                      onTap: onPoke,
                      borderRadius: BorderRadius.circular(18),
                      child: const SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(Icons.waving_hand_rounded,
                            size: 21, color: OunColors.tabAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OunColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: OunColors.textMuted)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        color: OunColors.cardBorder,
      );
}
