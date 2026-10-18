import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/floating_tab_bar.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../character/character_avatar.dart';
import '../character/character_mood.dart';
import '../my/care_screen.dart';
import '../my/notifications_screen.dart';
import '../quest/quest_screen.dart';

/// 캐릭터 우선 홈(A안 · 차분한 무대).
/// 상단은 인사·코인으로 최소화해 캐릭터에 무대를 내주고,
/// 하단 프로스티드 카드 하나에 오늘의 스탯 + CTA를 모은다.
///
/// 캐릭터는 미리 렌더한 레이어 PNG를 겹친 [LivingCharacter]다(엔진 없음).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 이번 세션에서 응원 반응을 이미 재생했는지. 홈은 IndexedStack으로 계속
  /// 살아있어서, 이 플래그가 없으면 리빌드마다 캐릭터가 다시 반응한다.
  bool _cheerHandled = false;

  /// 기분 말풍선: 기분을 처음 받거나 바뀌었을 때, 캐릭터를 탭할 때 잠깐 뜬다.
  int _bubbleTurn = MoodLook.randomTurn();
  bool _bubbleVisible = false;
  Timer? _bubbleTimer;

  void _showBubble({bool next = false}) {
    _bubbleTimer?.cancel();
    setState(() {
      if (next && _bubbleVisible) _bubbleTurn++;
      _bubbleVisible = true;
    });
    _bubbleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _bubbleVisible = false);
    });
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    super.dispose();
  }

  void _pokeCharacter() => ref.read(characterReactionProvider.notifier).play();

  /// 미확인 응원이 있으면 캐릭터가 한 번 반응하고 확인 처리한다.
  Future<void> _playCheerReaction(ReceivedCheers cheers) async {
    if (_cheerHandled || cheers.unseen == 0) return;
    _cheerHandled = true;

    ref.read(characterReactionProvider.notifier).play();

    final unseen = cheers.items.where((c) => !c.seen).toList();
    if (unseen.isNotEmpty && mounted) {
      final first = unseen.first;
      final msg = cheers.unseen == 1
          ? '${first.fromDisplayName}님이 응원을 보냈어요 ${first.emoji}'
          : '${first.fromDisplayName}님 외 ${cheers.unseen - 1}명이 응원을 보냈어요';
      OunToast.show(context, msg, kind: OunToastKind.cheer);
    }

    try {
      await ref.read(apiClientProvider).markCheersSeen();
      ref.invalidate(receivedCheersProvider);
    } catch (_) {
      // 확인 처리 실패 → 다음 진입에 다시 반응하도록 되돌린다.
      _cheerHandled = false;
    }
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
    // 미확인 응원이 있으면 첫 프레임 뒤에 캐릭터가 반응한다.
    // (빌드 중에 프로바이더·토스트를 건드리지 않도록 post-frame으로 미룬다)
    final cheers = ref.watch(receivedCheersProvider).value;
    if (cheers != null && cheers.unseen > 0 && !_cheerHandled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playCheerReaction(cheers);
      });
    }

    // 기분이 처음 들어오거나 바뀌면 말풍선으로 한마디 한다.
    ref.listen(characterMoodProvider, (prev, next) {
      final m = next.value;
      if (m == null) return;
      final before = prev?.value;
      if (before?.mood == m.mood && before?.restingToday == m.restingToday) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBubble();
      });
    });
    final mood = MoodLook.of(ref.watch(characterMoodProvider).value);

    final look = CharacterLook(
      gender: ref.watch(authProvider.select((a) => a.profile?.gender)) ?? 'f',
      equipment: ref.watch(equippedItemsProvider).value ?? const {},
      specialFx: ref.watch(specialFxProvider).value ?? const {},
    );
    final safe = MediaQuery.viewPaddingOf(context);

    return Stack(
      children: [
        const Positioned.fill(child: _HomeBackdrop()),
        // 캐릭터 무대: 인사줄 아래부터 오늘 카드 윗부분까지.
        Positioned(
          left: 24,
          right: 24,
          top: safe.top + 64,
          bottom: safe.bottom + FloatingTabBar.reservedSpace + 150,
          child: Align(
            // 인사줄과 오늘 카드 사이 가운데보다 살짝 위 — 말풍선 자리를 남긴다.
            alignment: const Alignment(0, 0.175),
            child: ConstrainedBox(
              // 화면을 꽉 채우면 부담스럽다 — 카드 위에 아담하게 서 있도록.
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 312),
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    LivingCharacter(
                      look: look,
                      restFace: mood.face,
                      reactToProvider: true,
                      onTap: mood.lines.isEmpty
                          ? null
                          : () => _showBubble(next: true),
                    ),
                    // 말꼬리 끝이 정수리(캔버스 위 9%) 바로 위에 오도록.
                    if (mood.lines.isNotEmpty)
                      Positioned(
                        left: -40,
                        right: -40,
                        bottom: c.maxHeight * 0.91,
                        child: Center(
                          child: MoodBubble(
                            text: mood.line(_bubbleTurn),
                            visible: _bubbleVisible,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 하단 그라데이션 스크림: 캐릭터 발밑이 배경 바닥으로 부드럽게
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
        const _NotificationButton(),
        const SizedBox(width: 7),
        const _QuestButton(),
        const SizedBox(width: 7),
        const _CoinPill(),
      ],
    );
  }
}

/// 알림·받은 응원 진입 버튼. 안 읽은 알림이 있으면 점 배지를 띄운다.
///
/// 응원은 홈에서 캐릭터가 반응하는 기능이라, 그 근거를 다시 보는 입구도
/// 홈에 두는 게 자연스럽다(마이 탭 안쪽까지 들어가지 않아도 되도록).
class _NotificationButton extends ConsumerWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    return Material(
      color: OunColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 34,
          height: 30,
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.notifications_rounded,
                    size: 16, color: OunColors.tabAccent),
              ),
              if (unread > 0)
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
    final care = ref.watch(careProvider).value;
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
              // 휴식일: 오늘 쉬는 중이면 안내, 아직 선언할 수 있으면 조용한 링크.
              if (care != null && (care.restToday || care.canDeclareRest))
                _RestDayRow(care: care),
            ],
          ),
        ),
      ),
    );
  }
}

/// 오늘 카드 아래 휴식일 줄.
class _RestDayRow extends ConsumerWidget {
  const _RestDayRow({required this.care});
  final CareStatus care;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resting = care.restToday;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: resting ? null : () => confirmRestDay(context, ref, care),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bedtime_outlined,
                  size: 15, color: OunColors.textMuted),
              const SizedBox(width: 5),
              Text(
                resting
                    ? '오늘은 쉬는 날 · 연속 기록은 그대로 이어져요'
                    : '오늘은 쉬어 갈래요 · +${care.restReward} 코인',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OunColors.textMuted),
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


/// 홈 무대 배경: 위는 따뜻한 하늘, 아래는 캐릭터가 서 있는 동그란 잔디 언덕.
class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF4E8), OunColors.background],
        ),
      ),
      child: Align(
        // 캐릭터 발밑에 잔디 언덕이 오도록(캐릭터 무대 위치와 같이 움직인다).
        alignment: const Alignment(0, 0.33),
        child: FractionallySizedBox(
          widthFactor: 1.5,
          child: AspectRatio(
            aspectRatio: 3.2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.75,
                  colors: [
                    const Color(0xFFDDEBC4),
                    const Color(0xFFDDEBC4).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
