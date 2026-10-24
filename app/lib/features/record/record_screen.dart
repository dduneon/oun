import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workout_editor.dart';
import '../health/health_import_screen.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/action_sheet.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/photo_viewer.dart';
import '../../theme/app_theme.dart';

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

void _openHistory(BuildContext context, {DateTime? date}) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => _WorkoutHistory(date: date)));
}

Future<void> _openDetail(BuildContext context, Workout workout) async {
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => _WorkoutDetail(workout: workout)),
  );
}

class _WorkoutHistory extends ConsumerStatefulWidget {
  const _WorkoutHistory({this.date});
  final DateTime? date;
  @override
  ConsumerState<_WorkoutHistory> createState() => _WorkoutHistoryState();
}

class _WorkoutHistoryState extends ConsumerState<_WorkoutHistory> {
  final List<Workout> _items = [];
  bool _loading = false;
  bool _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final date = widget.date;
      final items = await ref
          .read(apiClientProvider)
          .workouts(
            from: date,
            to: date
                ?.add(const Duration(days: 1))
                .subtract(const Duration(milliseconds: 1)),
            offset: reset ? 0 : _items.length,
          );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _more = items.length == 50;
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, '기록을 불러오지 못했어요'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OunColors.background,
    appBar: _ounAppBar(
      context,
      widget.date == null
          ? '전체 운동 기록'
          : '${widget.date!.month}월 ${widget.date!.day}일 기록',
    ),
    body: RefreshIndicator(
      color: OunColors.tabAccent,
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final w in _items)
            _RecordRow(
              sportIcons[w.sport] ?? Icons.fitness_center,
              w.customSportName?.isNotEmpty == true
                  ? w.customSportName!
                  : sportLabels[w.sport] ?? w.sport,
              '${w.performedAt.year}.${w.performedAt.month}.${w.performedAt.day} · ${workoutMetric(w)}',
              '${w.minutes}분',
              photoUrl: w.photoUrl,
              onTap: () async {
                await _openDetail(context, w);
                await _load(reset: true);
              },
            ),
          if (!_loading && _items.isEmpty && _error == null)
            const _EmptyHint('아직 운동 기록이 없어요'),
          if (_error != null) Text(_error!),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: OunColors.tabAccent),
            )
          else if (_more || _error != null)
            TextButton(
              onPressed: _load,
              style: TextButton.styleFrom(foregroundColor: OunColors.tabAccent),
              child: Text(_error == null ? '더 보기' : '다시 시도'),
            ),
        ],
      ),
    ),
  );
}

/// 오운 톤 상단바: 배경과 이어지는 평평한 바 + iOS 뒤로가기.
PreferredSizeWidget _ounAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
}) => AppBar(
  backgroundColor: OunColors.background,
  elevation: 0,
  scrolledUnderElevation: 0,
  surfaceTintColor: Colors.transparent,
  centerTitle: true,
  title: Text(
    title,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: OunColors.textPrimary,
    ),
  ),
  leading: IconButton(
    onPressed: () => Navigator.of(context).maybePop(),
    icon: const Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 18,
      color: OunColors.textPrimary,
    ),
    tooltip: '뒤로',
  ),
  actions: actions,
);

/// '2026년 10월 6일 (화) · 오후 3:20'
String _detailDate(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.year}년 ${d.month}월 ${d.day}일 (${'월화수목금토일'[d.weekday - 1]}) · '
      '${d.hour < 12 ? '오전' : '오후'} $h:${d.minute.toString().padLeft(2, '0')}';
}

String _kg(double n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();

class _WorkoutDetail extends ConsumerWidget {
  const _WorkoutDetail({required this.workout});
  final Workout workout;

  Future<void> _openEditor(BuildContext context, {bool repeat = false}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkoutEditor(editing: workout, repeat: repeat),
    );
    if (saved == true && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = workout;
    final sport = sportLabels[w.sport] ?? w.sport;
    final hasName = w.customSportName?.isNotEmpty == true;
    // 제목·칩에서 이미 보이는 종목/이름은 표에서 뺀다.
    final rows = workoutDetails(
      w,
    ).where((r) => r.$1 != '종목' && r.$1 != '운동 이름').toList();
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: _ounAppBar(
        context,
        '운동 기록',
        actions: [
          IconButton(
            onPressed: () => showOunActionSheet(
              context,
              actions: [
                OunAction(
                  label: '수정',
                  icon: Icons.edit_outlined,
                  onSelected: () => _openEditor(context),
                ),
                OunAction(
                  label: '삭제',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  onSelected: () async {
                    final deleted = await _deleteWorkoutFlow(
                      context,
                      ref,
                      w.id,
                    );
                    if (deleted && context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: OunColors.textPrimary,
            ),
            tooltip: '더보기',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          // 히어로: 종목 아이콘 + 이름 + 날짜
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: OunColors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: OunColors.surface,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    sportIcons[w.sport] ?? Icons.fitness_center,
                    size: 28,
                    color: OunColors.tabAccent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasName)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            sport,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: OunColors.tabAccent,
                            ),
                          ),
                        ),
                      Text(
                        hasName ? w.customSportName! : sport,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: OunColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_detailDate(w.performedAt)}${w.source == 'healthkit' ? ' · 애플 건강' : w.source == 'health_connect' ? ' · Health Connect' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: OunColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _SectionHeader('기록', showAll: false),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _listCard,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: OunColors.card),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rows[i].$1,
                            style: const TextStyle(
                              fontSize: 13,
                              color: OunColors.textMuted,
                            ),
                          ),
                        ),
                        Text(
                          rows[i].$2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (w.exercises.isNotEmpty) ...[
            const _SectionHeader('운동 · 세트', showAll: false),
            for (final e in w.exercises)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                decoration: _listCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OunColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < e.sets.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: OunColors.card,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: OunColors.tabAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '세트',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: OunColors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_kg(e.sets[i].weightKg)} kg × ${e.sets[i].reps}회',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: OunColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (w.note?.isNotEmpty == true) ...[
            const _SectionHeader('메모', showAll: false),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _listCard,
              child: Text(
                w.note!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: OunColors.textPrimary,
                ),
              ),
            ),
          ],
          if (w.photoUrl != null) ...[
            const _SectionHeader('사진', showAll: false),
            GestureDetector(
              onTap: () => showPhotoViewer(context, w.photoUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    w.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: OunColors.card,
                      child: Center(
                        child: Text(
                          '사진을 불러오지 못했어요',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: OunColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: OunColors.tabAccent,
              foregroundColor: OunColors.onTabAccent,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _openEditor(context, repeat: true),
            icon: const Icon(Icons.replay_rounded, size: 19),
            label: const Text(
              '이 운동 다시 기록하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// 밝은 리스트 카드(기록 행과 같은 톤).
final _listCard = BoxDecoration(
  color: OunColors.surface,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: OunColors.cardBorder),
);

/// 운동 기록·입력. 주간 스트릭 + 종목 퀵스타트 + 최근 기록. (서버 데이터)
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return PageScaffold(
      title: '기록',
      onRefresh: () => refreshTab(ref, OunTab.record),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: OunColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: Text(
          '${now.month}월',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: OunColors.textPrimary,
          ),
        ),
      ),
      children: [
        const _MonthSection(),
        const _SectionHeader('오늘 기록하기', showAll: false),
        Row(
          children: [
            Expanded(
              child: _QuickStart(
                Icons.directions_run,
                '러닝',
                onTap: () => _openSheet(context, '러닝', Icons.directions_run),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _QuickStart(
                Icons.directions_walk,
                '걷기',
                onTap: () => _openSheet(context, '걷기', Icons.directions_walk),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _QuickStart(
                Icons.fitness_center,
                '웨이트',
                onTap: () => _openSheet(context, '웨이트', Icons.fitness_center),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _QuickStart(
                Icons.directions_bike,
                '자전거',
                onTap: () => _openSheet(context, '자전거', Icons.directions_bike),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: OunColors.tabAccent,
              side: const BorderSide(color: OunColors.cardBorder),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _openSheet(context, null, null),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text(
              '다른 운동 기록하기',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => openHealthImport(context),
          icon: const Icon(Icons.favorite_outline),
          label: const Text('건강 앱에서 최근 운동 불러오기'),
        ),
        Row(
          children: [
            const Expanded(child: _SectionHeader('최근 기록', showAll: false)),
            TextButton(
              onPressed: () => _openHistory(context),
              child: const Text('전체 보기'),
            ),
          ],
        ),
        const _RecentRecords(),
      ],
    );
  }

  void _openSheet(BuildContext context, String? preset, IconData? icon) {
    showModalBottomSheet<void>(
      context: context,
      // 루트 네비게이터에 띄워야 플로팅 탭바 위로 올라온다.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkoutEditor(preset: preset),
    );
  }
}

/// 최근 기록 목록(서버).
class _RecentRecords extends ConsumerWidget {
  const _RecentRecords();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentWorkoutsProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: OunColors.tabAccent,
            ),
          ),
        ),
      ),
      error: (_, _) => const _EmptyHint('기록을 불러오지 못했어요'),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyHint('첫 운동을 기록해 보세요');
        }
        return Column(
          children: [
            for (final w in items.take(5))
              _RecordRow(
                sportIcons[w.sport] ?? Icons.sports_gymnastics,
                sportLabels[w.sport] ?? w.sport,
                '${relativeDay(w.performedAt)} · ${workoutMetric(w)}',
                '${w.minutes}분',
                photoUrl: w.photoUrl,
                onTap: () => _openDetail(context, w),
                onEdit: () => _openEditWorkoutSheet(context, w),
                onDelete: () => _deleteWorkoutFlow(context, ref, w.id),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: OunColors.textFaint),
      ),
    ),
  );
}

/// 주간 스트립 + 펼치면 월간 도트 캘린더 + 월 요약. (서버 캘린더/요약)
class _MonthSection extends ConsumerStatefulWidget {
  const _MonthSection();

  @override
  ConsumerState<_MonthSection> createState() => _MonthSectionState();
}

class _MonthSectionState extends ConsumerState<_MonthSection> {
  bool _expanded = false;
  DateTime _month = DateTime.now(); // 월간 보기에서 넘겨보는 달

  static const _weekLabels = ['월', '화', '수', '목', '금', '토', '일'];
  // 강도별 색 (1~4). 0은 점 없음.
  static const _heat = [
    OunColors.card,
    Color(0xFFEBCBA9),
    Color(0xFFDDA774),
    Color(0xFFC97F44),
    Color(0xFFA85E28),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentKey = _monthKey(now);
    final calendar = ref.watch(calendarProvider(currentKey)).value ?? [];
    final profile = ref.watch(profileProvider).value;

    // 이번 주(월~일) 완료 여부: 이번 달 캘린더에서 계산
    final doneDates = calendar
        .where((d) => d.intensity > 0)
        .map((d) => d.date)
        .toSet();
    final todayIdx = now.weekday - 1;
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: todayIdx));
    final weekDone = List<bool>.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return doneDates.contains(key);
    });
    final weekCount = weekDone.where((b) => b).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        children: [
          // 주간 스트립
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _DayDot(
                  label: _weekLabels[i],
                  done: weekDone[i],
                  isToday: i == todayIdx,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12, color: OunColors.textMuted),
              children: [
                const TextSpan(text: '이번 주 '),
                TextSpan(
                  text: '$weekCount일',
                  style: const TextStyle(
                    color: OunColors.tabAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: ' 운동 · 연속 ${profile?.streakCurrent ?? 0}일'),
              ],
            ),
          ),
          if (_expanded) _monthly(),
          _toggle(),
        ],
      ),
    );
  }

  Widget _toggle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: OunColors.cardBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded ? '접기' : '월간 보기',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OunColors.tabAccent,
              ),
            ),
            Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: OunColors.tabAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthly() {
    final key = _monthKey(_month);
    final calendar = ref.watch(calendarProvider(key)).value ?? [];
    final summary = ref.watch(monthSummaryProvider(key)).value;
    final intensityByDay = {
      for (final d in calendar) int.parse(d.date.substring(8)): d.intensity,
    };

    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '${_month.year}년 ${_month.month}월',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary,
              ),
            ),
            const Spacer(),
            _navArrow(
              Icons.chevron_left_rounded,
              () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
            ),
            const SizedBox(width: 6),
            _navArrow(
              Icons.chevron_right_rounded,
              () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 월 요약
        Row(
          children: [
            Expanded(
              child: _MonthStat(
                value: '${summary?.workoutDays ?? 0}',
                label: '운동한 날',
              ),
            ),
            const _StatSep(),
            Expanded(
              child: _MonthStat(
                value:
                    '${((summary?.totalMinutes ?? 0) / 60).toStringAsFixed(1)}h',
                label: '총 시간',
              ),
            ),
            const _StatSep(),
            Expanded(
              child: _MonthStat(
                value: '${summary?.longestStreak ?? 0}일',
                label: '최장 연속',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _calendarGrid(intensityByDay),
      ],
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: OunColors.tabAccent),
    ),
  );

  Widget _calendarGrid(Map<int, int> intensityByDay) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingEmpty = DateTime(_month.year, _month.month, 1).weekday - 1;
    final now = DateTime.now();
    final todayDay = (_month.year == now.year && _month.month == now.month)
        ? now.day
        : -1;

    final weeks = <Widget>[];
    var day = 1 - leadingEmpty;
    final total = leadingEmpty + daysInMonth;
    final weekCount = (total / 7).ceil();
    for (var w = 0; w < weekCount; w++) {
      final row = <Widget>[];
      for (var i = 0; i < 7; i++) {
        row.add(
          Expanded(
            child: (day < 1 || day > daysInMonth)
                ? const SizedBox(height: 38)
                : _dayCell(day, intensityByDay[day] ?? 0, day == todayDay),
          ),
        );
        day++;
      }
      weeks.add(Row(children: row));
    }
    return Column(
      children: [
        Row(
          children: [
            for (final l in _weekLabels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: OunColors.textFaint,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ...weeks,
      ],
    );
  }

  Widget _dayCell(int d, int v, bool isToday) {
    return InkWell(
      onTap: () =>
          _openHistory(context, date: DateTime(_month.year, _month.month, d)),
      child: Container(
        height: 38,
        margin: const EdgeInsets.all(1),
        decoration: isToday
            ? BoxDecoration(
                color: OunColors.card,
                borderRadius: BorderRadius.circular(9),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$d',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                color: OunColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: v > 0 ? _heat[v.clamp(0, 4)] : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 월 요약 통계 한 칸.
class _MonthStat extends StatelessWidget {
  const _MonthStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: OunColors.textPrimary,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 9.5, color: OunColors.textMuted),
      ),
    ],
  );
}

class _StatSep extends StatelessWidget {
  const _StatSep();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: OunColors.cardBorder);
}

/// 주간 스트릭 하루 표시. 완료일은 체크, 오늘은 링으로 강조.
class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.done,
    required this.isToday,
  });
  final String label;
  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done ? OunColors.tabAccent : OunColors.card,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: OunColors.seed, width: 2)
                : done
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
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: isToday ? OunColors.textPrimary : OunColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _QuickStart extends StatelessWidget {
  const _QuickStart(this.icon, this.label, {required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(
            children: [
              Icon(icon, size: 26, color: OunColors.tabAccent),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OunColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.showAll = true});
  final String text;
  final bool showAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OunColors.textPrimary,
            ),
          ),
        ),
        if (showAll)
          GestureDetector(
            onTap: () {},
            child: const Text(
              '전체 보기',
              style: TextStyle(fontSize: 11.5, color: OunColors.textMuted),
            ),
          ),
      ],
    ),
  );
}

/// 운동 기록 수정 시트를 연다(기존 값 프리필).
void _openEditWorkoutSheet(BuildContext context, Workout w) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WorkoutEditor(editing: w),
  );
}

/// 운동 기록 삭제(확인 후). 코인 회수 안내 포함. 삭제됐으면 true.
Future<bool> _deleteWorkoutFlow(
  BuildContext context,
  WidgetRef ref,
  String workoutId,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: OunColors.background,
      title: const Text(
        '운동 기록을 삭제할까요?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: const Text(
        '이 기록으로 받은 코인은 회수돼요.',
        style: TextStyle(fontSize: 13, color: OunColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소', style: TextStyle(color: OunColors.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('삭제', style: TextStyle(color: Color(0xFFCC4B37))),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await ref.read(apiClientProvider).deleteWorkout(workoutId);
    invalidateAfterWorkout(ref);
    if (context.mounted) {
      OunToast.show(context, '운동 기록을 삭제했어요', kind: OunToastKind.info);
    }
    return true;
  } catch (_) {
    if (context.mounted) OunToast.show(context, '삭제에 실패했어요');
    return false;
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(
    this.icon,
    this.title,
    this.sub,
    this.value, {
    this.photoUrl,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String sub;
  final String value;
  final String? photoUrl;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              child: Icon(icon, size: 19, color: OunColors.tabAccent),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: OunColors.textPrimary,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11,
                      color: OunColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (photoUrl != null) ...[
              GestureDetector(
                onTap: () => showPhotoViewer(context, photoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photoUrl!,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary,
              ),
            ),
            if (onEdit != null || onDelete != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showOunActionSheet(
                  context,
                  actions: [
                    if (onEdit != null)
                      OunAction(
                        label: '수정',
                        icon: Icons.edit_outlined,
                        onSelected: onEdit!,
                      ),
                    if (onDelete != null)
                      OunAction(
                        label: '삭제',
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                        onSelected: onDelete!,
                      ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 19,
                    color: OunColors.textFaint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
