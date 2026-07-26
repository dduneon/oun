import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 친구 홈: 친구의 아바타(정적 표현) + 운동량 요약 + 최근 활동 + 응원. (서버)
///
/// 실시간 3D 아바타는 홈 탭의 단일 Unity 인스턴스 제약으로 띄울 수 없어,
/// 여기서는 정적 표현(추후 서버 렌더 스냅샷으로 교체)을 쓴다.
class FriendHomeScreen extends ConsumerWidget {
  const FriendHomeScreen({
    super.key,
    required this.nickname,
    required this.displayName,
  });

  final String nickname;
  final String displayName;

  static const _week = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendHomeProvider(nickname));
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: Text('$displayName님의 홈',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OunColors.tabAccent)),
        error: (_, _) => const Center(
          child: Text('프로필을 불러오지 못했어요',
              style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
        data: (home) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            _avatarStage(home),
            const SizedBox(height: 14),
            _statRow(home),
            const SizedBox(height: 22),
            const _Label('이번 주'),
            const SizedBox(height: 10),
            _weekStrip(home),
            const SizedBox(height: 22),
            const _Label('최근 활동'),
            const SizedBox(height: 10),
            if (home.recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text('아직 기록이 없어요',
                      style:
                          TextStyle(fontSize: 12, color: OunColors.textFaint)),
                ),
              )
            else
              for (final w in home.recent)
                _ActivityRow(
                  sportIcons[w.sport] ?? Icons.sports_gymnastics,
                  sportLabels[w.sport] ?? w.sport,
                  '${relativeDay(w.performedAt)} · ${workoutMetric(w)}',
                  '${w.minutes}분',
                ),
            const SizedBox(height: 24),
            _CheerButton(nickname: nickname, displayName: displayName),
          ],
        ),
      ),
    );
  }

  /// 아바타 무대(정적). 실제로는 캐릭터 렌더 스냅샷이 들어갈 자리.
  Widget _avatarStage(FriendHome home) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
                color: avatarColor(nickname), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initialOf(displayName),
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(height: 14),
          Text('@$nickname',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Lv.${home.level} · 연속 ${home.streakCurrent}일',
              style: const TextStyle(fontSize: 12, color: OunColors.textMuted)),
        ],
      ),
    );
  }

  Widget _statRow(FriendHome home) {
    return Row(
      children: [
        Expanded(
            child: _Stat(value: '${home.streakCurrent}일', label: '연속 기록')),
        const SizedBox(width: 9),
        Expanded(child: _Stat(value: '${home.weekCount}일', label: '이번 주')),
        const SizedBox(width: 9),
        Expanded(
            child: _Stat(
                value: '${(home.weekMinutes / 60).toStringAsFixed(1)}h',
                label: '이번 주 시간')),
      ],
    );
  }

  Widget _weekStrip(FriendHome home) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (i < home.weekDone.length && home.weekDone[i])
                        ? OunColors.tabAccent
                        : OunColors.card,
                    shape: BoxShape.circle,
                    border: i == todayIndex
                        ? Border.all(color: OunColors.seed, width: 2)
                        : (i < home.weekDone.length && home.weekDone[i])
                            ? null
                            : Border.all(color: OunColors.cardBorder),
                  ),
                  child: (i < home.weekDone.length && home.weekDone[i])
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: OunColors.onTabAccent)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(_week[i],
                    style: const TextStyle(
                        fontSize: 10, color: OunColors.textMuted)),
              ],
            ),
        ],
      ),
    );
  }

}

/// 응원 보내기 버튼. 전송 중에는 비활성화한다 — 연타하면 그만큼 상대 폰에
/// 푸시가 나가기 때문(서버도 하루 상한을 두지만 실수 연타는 여기서 막는다).
class _CheerButton extends ConsumerStatefulWidget {
  const _CheerButton({required this.nickname, required this.displayName});

  final String nickname;
  final String displayName;

  @override
  ConsumerState<_CheerButton> createState() => _CheerButtonState();
}

class _CheerButtonState extends ConsumerState<_CheerButton> {
  bool _sending = false;

  Future<void> _cheer() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).cheer(widget.nickname, emoji: '❤️');
      ref.invalidate(friendsProvider);
      ref.invalidate(questsProvider);
      if (mounted) {
        OunToast.show(context, '${widget.displayName}님에게 응원을 보냈어요',
            kind: OunToastKind.cheer);
      }
    } catch (e) {
      if (mounted) OunToast.show(context, apiErrorMessage(e, '응원에 실패했어요'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: OunColors.tabAccent,
          foregroundColor: OunColors.onTabAccent,
          disabledBackgroundColor: OunColors.cardBorder,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _sending ? null : _cheer,
        icon: const Icon(Icons.favorite_rounded, size: 18),
        label: const Text('응원 보내기',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: OunColors.textPrimary));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OunColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: OunColors.textMuted)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.icon, this.title, this.sub, this.value);
  final IconData icon;
  final String title;
  final String sub;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: OunColors.card, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: OunColors.tabAccent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: OunColors.textPrimary)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: OunColors.textMuted)),
              ],
            ),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
        ],
      ),
    );
  }
}
