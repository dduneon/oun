import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';
import '../character/character_avatar.dart';

void openWeeklyReview(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const WeeklyReviewScreen()));

/// 주간 운동 회고. 서버가 집계하고 앱은 보여 주기만 한다.
/// 줄어든 수치를 탓하지 않는다 — 늘어난 것만 강조하고 나머지는 담담하게.
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});
  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  String? _week;
  void _shift(String start, int days) => setState(() {
    _week = DateTime.parse(
      '${start}T00:00:00Z',
    ).add(Duration(days: days)).toIso8601String().substring(0, 10);
  });

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weeklyReviewProvider(_week));
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text(
          '주간 운동 회고',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: OunColors.textPrimary,
          ),
        ),
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: OunColors.tabAccent),
        ),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '회고를 불러오지 못했어요',
                style: TextStyle(fontSize: 13, color: OunColors.textMuted),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: OunColors.tabAccent,
                ),
                onPressed: () => ref.invalidate(weeklyReviewProvider(_week)),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        data: (review) => RefreshIndicator(
          color: OunColors.tabAccent,
          backgroundColor: OunColors.surface,
          onRefresh: () async {
            ref.invalidate(weeklyReviewProvider(_week));
            await ref.read(weeklyReviewProvider(_week).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              Center(
                child: _WeekPicker(
                  review: review,
                  onPrev: () => _shift(review.weekStart, -7),
                  onNext: review.isCurrentWeek
                      ? null
                      : () => _shift(review.weekStart, 7),
                  onToday: review.isCurrentWeek
                      ? null
                      : () => setState(() => _week = null),
                ),
              ),
              const SizedBox(height: 14),
              _Hero(review: review),
              const _Label('운동한 날'),
              _Card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < review.daily.length; i++)
                      Expanded(
                        child: _DayColumn(
                          day: review.daily[i],
                          label: '월화수목금토일'[i],
                        ),
                      ),
                  ],
                ),
              ),
              _Label('${review.comparison} 비교'),
              Row(
                children: [
                  Expanded(
                    child: _CompareTile(
                      label: '운동한 날',
                      current: review.current.days,
                      previous: review.previous.days,
                      unit: '일',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompareTile(
                      label: '운동 시간',
                      current: review.current.minutes,
                      previous: review.previous.minutes,
                      unit: '분',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompareTile(
                      label: '운동 횟수',
                      current: review.current.sessions,
                      previous: review.previous.sessions,
                      unit: '회',
                    ),
                  ),
                ],
              ),
              if (review.sports.isNotEmpty) ...[
                const _Label('이 주에 한 운동'),
                for (final sport in review.sports) _SportRow(sport: sport),
              ],
              const SizedBox(height: 14),
              const Text(
                '한국 시간 기준 월요일부터 일요일까지,\n인증된 운동 기록을 집계해요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: OunColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ‹ 10.19 – 10.25 › 주 이동 칩. 지난 주를 보고 있으면 '이번 주로'가 붙는다.
class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.review,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });
  final WeeklyReview review;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    String md(String d) => d.substring(5).replaceAll('-', '.');
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: OunColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OunColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ArrowButton(
                icon: Icons.chevron_left_rounded,
                tooltip: '이전 주',
                onTap: onPrev,
              ),
              Text(
                '${md(review.weekStart)} – ${md(review.weekEnd)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary,
                ),
              ),
              _ArrowButton(
                icon: Icons.chevron_right_rounded,
                tooltip: '다음 주',
                onTap: onNext,
              ),
            ],
          ),
        ),
        if (onToday != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: OunColors.tabAccent,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onToday,
            child: const Text(
              '이번 주로',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    color: OunColors.tabAccent,
    disabledColor: OunColors.cardBorder,
    icon: Icon(icon, size: 22),
  );
}

/// 한 주 요약: 캐릭터와 함께 따뜻한 한마디. (월간 리포트 카드와 같은 톤)
class _Hero extends ConsumerWidget {
  const _Hero({required this.review});
  final WeeklyReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = CharacterLook(
      gender: ref.watch(authProvider.select((a) => a.profile?.gender)) ?? 'f',
      equipment: ref.watch(equippedItemsProvider).value ?? const {},
      specialFx: ref.watch(specialFxProvider).value ?? const {},
    );
    final c = review.current;
    final rested = c.days == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.isCurrentWeek ? '이번 주 · 진행 중' : '이 주의 나',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OunColors.tabAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rested ? '잠깐 쉬어 가도 괜찮아요' : '${c.days}일, 나를 위해 움직였어요',
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: OunColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.sessions == 0
                      ? '이 주에 기록한 운동이 아직 없어요. 빠뜨린 운동이 있다면 기록해 주세요.'
                      : '${c.sessions}번의 운동, 총 ${c.minutes}분을 쌓았어요.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: OunColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 84,
            child: CharacterFigure(
              look: look,
              face: rested ? CharacterFace.sleepy : CharacterFace.happy,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 20, 2, 9),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: OunColors.textPrimary,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    decoration: BoxDecoration(
      color: OunColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: OunColors.cardBorder),
    ),
    child: child,
  );
}

/// 기록 탭 주간 스트립과 같은 동그라미 + 그날 운동 시간.
class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.label});
  final WeeklyDay day;
  final String label;
  @override
  Widget build(BuildContext context) {
    final done = day.sessions > 0;
    return Semantics(
      label: '${day.date} ${day.sessions}회',
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: done ? OunColors.tabAccent : OunColors.card,
              shape: BoxShape.circle,
              border: done || day.future
                  ? null
                  : Border.all(color: OunColors.cardBorder),
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: OunColors.onTabAccent,
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: OunColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            !done
                ? ' '
                : day.minutes == 0
                ? '${day.sessions}회'
                : '${day.minutes}분',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: OunColors.tabAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// 이번 값 + 비교. 늘었을 때만 테라코타 칩, 아니면 이전 값을 담담하게.
class _CompareTile extends StatelessWidget {
  const _CompareTile({
    required this.label,
    required this.current,
    required this.previous,
    required this.unit,
  });
  final String label, unit;
  final int current, previous;

  @override
  Widget build(BuildContext context) {
    final up = current - previous;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: OunColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '$current$unit',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: OunColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (up > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: OunColors.tabAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$up$unit',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OunColors.tabAccent,
                ),
              ),
            )
          else
            Text(
              up == 0 ? '이전과 같아요' : '이전 $previous$unit',
              style: const TextStyle(fontSize: 11, color: OunColors.textFaint),
            ),
        ],
      ),
    );
  }
}

class _SportRow extends StatelessWidget {
  const _SportRow({required this.sport});
  final WeeklySport sport;

  @override
  Widget build(BuildContext context) => Container(
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
            color: OunColors.card,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            sportIcons[sport.sport] ?? Icons.sports_gymnastics,
            size: 19,
            color: OunColors.tabAccent,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            sportLabels[sport.sport] ?? sport.sport,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: OunColors.textPrimary,
            ),
          ),
        ),
        Text(
          '${sport.sessions}회 · ${sport.minutes}분',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: OunColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}
