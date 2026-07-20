import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/floating_tab_bar.dart';
import '../../theme/app_theme.dart';
import '../quest/quest_screen.dart';

/// 캐릭터 우선 홈(A안 · 차분한 무대).
/// 상단은 인사·코인으로 최소화해 3D 캐릭터에 무대를 내주고,
/// 하단 프로스티드 카드 하나에 오늘의 스탯 + CTA를 모은다.
///
/// Unity 뷰 자체는 앱 전역 [UnityHost]가 화면 뒤에 렌더한다. 홈 화면은
/// 투명하게 두어 그 캐릭터가 비쳐 보이고, 그 위에 UI만 얹는다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _pokeCharacter() => sendToUnity('OunBridge', 'React', 'workout');

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
        // 캐릭터는 앱 전역 UnityHost가 이 투명 화면 뒤에 렌더한다.
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
        const _QuestButton(),
        const SizedBox(width: 7),
        const _CoinPill(),
      ],
    );
  }
}

/// 퀘스트 진입 버튼. 받을 보상이 있으면(서버 판단) 점 배지를 띄운다.
class _QuestButton extends ConsumerWidget {
  const _QuestButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClaimable = ref.watch(questsProvider).maybeWhen(
          data: (b) => b.hasClaimable,
          orElse: () => false,
        );
    return Material(
      color: OunColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const QuestScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 34,
          height: 30,
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.flag_rounded,
                    size: 16, color: OunColors.tabAccent),
              ),
              if (hasClaimable)
                Positioned(
                top: 5,
                right: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFFD98A88), shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 코인 잔액 필. 서버 `GET /wallet` 값 그대로 표시(로딩 중엔 '—').
class _CoinPill extends ConsumerWidget {
  const _CoinPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = ref.watch(walletProvider).maybeWhen(
          data: comma,
          orElse: () => '—',
        );
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

/// 하단 프로스티드 카드: 오늘 스탯 3종(서버 값) + 기록 CTA.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.onRecord, required this.onPoke});
  final VoidCallback onRecord;
  final VoidCallback onPoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final todayMin = ref.watch(todayMinutesProvider).value;
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
              Row(
                children: [
                  Expanded(
                      child: _Stat(
                          value: profile == null
                              ? '—'
                              : '${profile.streakCurrent}일',
                          label: '연속 기록')),
                  const _StatDivider(),
                  Expanded(
                      child: _Stat(
                          value: todayMin == null ? '—' : '$todayMin분',
                          label: '오늘 운동')),
                  const _StatDivider(),
                  Expanded(
                      child: _Stat(
                          value:
                              profile == null ? '—' : 'Lv.${profile.level}',
                          label: '지구력')),
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
