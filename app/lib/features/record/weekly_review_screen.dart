import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';

void openWeeklyReview(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const WeeklyReviewScreen()));

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
        title: const Text('주간 운동 회고'),
        backgroundColor: OunColors.background,
        actions: [
          TextButton(
            onPressed: () => setState(() => _week = null),
            child: const Text('이번 주'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('회고를 불러오지 못했어요'),
              TextButton(
                onPressed: () => ref.invalidate(weeklyReviewProvider(_week)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (review) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(weeklyReviewProvider(_week));
            await ref.read(weeklyReviewProvider(_week).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 주',
                    onPressed: () => _shift(review.weekStart, -7),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          review.isCurrentWeek ? '이번 주 · 진행 중' : '한 주의 기록',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${review.weekStart.replaceAll('-', '.')} – ${review.weekEnd.substring(5).replaceAll('-', '.')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OunColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 주',
                    onPressed: review.isCurrentWeek
                        ? null
                        : () => _shift(review.weekStart, 7),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ReviewCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: OunColors.tabAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      review.current.days == 0
                          ? '잠깐 쉬어 가도 괜찮아요'
                          : '${review.current.days}일, 나를 위해 움직였어요',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: OunColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review.current.sessions == 0
                          ? '이 주에 기록한 운동이 아직 없어요. 빠뜨린 운동이 있다면 기록해 주세요.'
                          : '${review.current.sessions}번의 운동, 총 ${review.current.minutes}분을 쌓았어요. 작은 기록도 모두 나의 변화예요.',
                      style: const TextStyle(
                        height: 1.5,
                        color: OunColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '운동한 날',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _ReviewCard(
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
              const SizedBox(height: 18),
              Text(
                '${review.comparison} 비교',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _ReviewCard(
                child: Column(
                  children: [
                    _Comparison(
                      label: '운동한 날',
                      current: review.current.days,
                      previous: review.previous.days,
                      unit: '일',
                    ),
                    const Divider(),
                    _Comparison(
                      label: '운동 시간',
                      current: review.current.minutes,
                      previous: review.previous.minutes,
                      unit: '분',
                    ),
                    const Divider(),
                    _Comparison(
                      label: '운동 횟수',
                      current: review.current.sessions,
                      previous: review.previous.sessions,
                      unit: '회',
                    ),
                  ],
                ),
              ),
              if (review.sports.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  '이 주에 한 운동',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _ReviewCard(
                  child: Column(
                    children: [
                      for (final sport in review.sports)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                sportIcons[sport.sport],
                                color: OunColors.tabAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sportLabels[sport.sport] ?? sport.sport,
                                ),
                              ),
                              Text('${sport.sessions}회 · ${sport.minutes}분'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                '한국 시간 기준 월요일부터 일요일까지, 인증된 운동 기록을 집계해요.',
                style: TextStyle(fontSize: 11, color: OunColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: OunColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: OunColors.cardBorder),
    ),
    child: child,
  );
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.label});
  final WeeklyDay day;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: OunColors.textMuted),
      ),
      const SizedBox(height: 8),
      Semantics(
        label: '${day.date} ${day.sessions}회',
        child: CircleAvatar(
          radius: 15,
          backgroundColor: day.sessions > 0
              ? OunColors.tabAccent
              : OunColors.card,
          child: Icon(
            day.sessions > 0 ? Icons.check_rounded : Icons.remove_rounded,
            size: 17,
            color: day.sessions > 0
                ? OunColors.onTabAccent
                : OunColors.textFaint,
          ),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        day.future
            ? '예정'
            : day.sessions == 0
            ? '—'
            : day.minutes == 0
            ? '${day.sessions}회'
            : '${day.minutes}분',
        style: const TextStyle(fontSize: 10, color: OunColors.textMuted),
      ),
    ],
  );
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.label,
    required this.current,
    required this.previous,
    required this.unit,
  });
  final String label, unit;
  final int current, previous;
  @override
  Widget build(BuildContext context) {
    final difference = current - previous;
    return Row(
      children: [
        Expanded(child: Text(label)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$current$unit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              difference == 0
                  ? '이전과 같아요'
                  : '이전보다 ${difference.abs()}$unit ${difference > 0 ? '늘었어요' : '줄었어요'}',
              style: const TextStyle(fontSize: 11, color: OunColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class WeeklyReviewLink extends ConsumerWidget {
  const WeeklyReviewLink({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(weeklyReviewProvider(null)).value;
    return TextButton.icon(
      onPressed: () => openWeeklyReview(context),
      icon: const Icon(Icons.calendar_view_week_rounded, size: 17),
      label: Text(
        review == null
            ? '이번 주 운동 회고'
            : '이번 주 ${review.current.days}일 · ${review.current.minutes}분  회고 보기',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
