import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// 운동 기록·입력. 주간 스트릭 + 종목 퀵스타트 + 최근 기록. (서버 데이터)
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return PageScaffold(
      title: '기록',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: OunColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: Text('${now.month}월',
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      children: [
        const _MonthSection(),
        const _SectionHeader('오늘 기록하기', showAll: false),
        Row(
          children: [
            Expanded(
                child: _QuickStart(Icons.directions_run, '러닝',
                    onTap: () => _openSheet(context, '러닝', Icons.directions_run))),
            const SizedBox(width: 9),
            Expanded(
                child: _QuickStart(Icons.directions_walk, '걷기',
                    onTap: () =>
                        _openSheet(context, '걷기', Icons.directions_walk))),
            const SizedBox(width: 9),
            Expanded(
                child: _QuickStart(Icons.fitness_center, '웨이트',
                    onTap: () =>
                        _openSheet(context, '웨이트', Icons.fitness_center))),
            const SizedBox(width: 9),
            Expanded(
                child: _QuickStart(Icons.directions_bike, '자전거',
                    onTap: () =>
                        _openSheet(context, '자전거', Icons.directions_bike))),
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
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _openSheet(context, null, null),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('다른 운동 기록하기',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ),
        const _SectionHeader('최근 기록', showAll: false),
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
      builder: (_) => _RecordInputSheet(preset: preset, presetIcon: icon),
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
                    strokeWidth: 2.4, color: OunColors.tabAccent))),
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
          child: Text(text,
              style:
                  const TextStyle(fontSize: 12, color: OunColors.textFaint)),
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
    final doneDates = calendar.where((d) => d.intensity > 0).map((d) => d.date).toSet();
    final todayIdx = now.weekday - 1;
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: todayIdx));
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
                        fontWeight: FontWeight.w700)),
                TextSpan(
                    text: ' 운동 · 연속 ${profile?.streakCurrent ?? 0}일'),
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
            Text(_expanded ? '접기' : '월간 보기',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OunColors.tabAccent)),
            Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: OunColors.tabAccent),
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
            Text('${_month.year}년 ${_month.month}월',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
            const Spacer(),
            _navArrow(Icons.chevron_left_rounded,
                () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
            const SizedBox(width: 6),
            _navArrow(Icons.chevron_right_rounded,
                () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
          ],
        ),
        const SizedBox(height: 12),
        // 월 요약
        Row(
          children: [
            Expanded(
                child: _MonthStat(
                    value: '${summary?.workoutDays ?? 0}', label: '운동한 날')),
            const _StatSep(),
            Expanded(
                child: _MonthStat(
                    value:
                        '${((summary?.totalMinutes ?? 0) / 60).toStringAsFixed(1)}h',
                    label: '총 시간')),
            const _StatSep(),
            Expanded(
                child: _MonthStat(
                    value: '${summary?.longestStreak ?? 0}일', label: '최장 연속')),
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
    final todayDay =
        (_month.year == now.year && _month.month == now.month) ? now.day : -1;

    final weeks = <Widget>[];
    var day = 1 - leadingEmpty;
    final total = leadingEmpty + daysInMonth;
    final weekCount = (total / 7).ceil();
    for (var w = 0; w < weekCount; w++) {
      final row = <Widget>[];
      for (var i = 0; i < 7; i++) {
        row.add(Expanded(
          child: (day < 1 || day > daysInMonth)
              ? const SizedBox(height: 38)
              : _dayCell(day, intensityByDay[day] ?? 0, day == todayDay),
        ));
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
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9.5, color: OunColors.textFaint)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ...weeks,
      ],
    );
  }

  Widget _dayCell(int d, int v, bool isToday) {
    return Container(
      height: 38,
      margin: const EdgeInsets.all(1),
      decoration: isToday
          ? BoxDecoration(
              color: OunColors.card, borderRadius: BorderRadius.circular(9))
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$d',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                  color: OunColors.textPrimary)),
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
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OunColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 9.5, color: OunColors.textMuted)),
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
  const _DayDot({required this.label, required this.done, required this.isToday});
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
              ? const Icon(Icons.check_rounded,
                  size: 15, color: OunColors.onTabAccent)
              : null,
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                color:
                    isToday ? OunColors.textPrimary : OunColors.textMuted)),
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
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OunColors.textPrimary)),
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
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OunColors.textPrimary)),
            ),
            if (showAll)
              GestureDetector(
                onTap: () {},
                child: const Text('전체 보기',
                    style:
                        TextStyle(fontSize: 11.5, color: OunColors.textMuted)),
              ),
          ],
        ),
      );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(this.icon, this.title, this.sub, this.value);
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
                color: OunColors.card,
                borderRadius: BorderRadius.circular(11)),
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

/// 운동 기록 입력 바텀시트. 저장 시 서버에 제출하고 보상을 안내한다.
class _RecordInputSheet extends ConsumerStatefulWidget {
  const _RecordInputSheet({this.preset, this.presetIcon});
  final String? preset;
  final IconData? presetIcon;

  @override
  ConsumerState<_RecordInputSheet> createState() => _RecordInputSheetState();
}

class _RecordInputSheetState extends ConsumerState<_RecordInputSheet> {
  // 앱 종목/부위 라벨 → 서버 enum.
  static const _sportApi = {
    '러닝': 'running',
    '걷기': 'walking',
    '웨이트': 'weight',
    '자전거': 'cycling',
    '요가': 'yoga',
    '기타': 'etc',
  };
  static const _bodyApi = {'상체': 'upper', '하체': 'lower', '전신': 'full', '코어': 'core'};

  static const _types = [
    ('러닝', Icons.directions_run),
    ('걷기', Icons.directions_walk),
    ('웨이트', Icons.fitness_center),
    ('자전거', Icons.directions_bike),
    ('요가', Icons.self_improvement),
    ('기타', Icons.sports_gymnastics),
  ];
  static const _bodyParts = ['상체', '하체', '전신', '코어'];

  late int _selected;
  int _minutes = 30;
  // 종목별 지표
  double _distanceKm = 3.0;
  int _steps = 5000;
  int _sets = 3;
  int _bodyPart = 0;
  // 운동 인증 사진(목업: 실제 이미지 대신 첨부 여부만 관리).
  bool _photoAttached = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = _types.indexWhere((t) => t.$1 == widget.preset);
    _selected = i < 0 ? 0 : i;
  }

  String get _type => _types[_selected].$1;

  /// 선택 종목에 필요한 추가 지표 종류. null이면 시간만.
  String? get _metricKind {
    switch (_type) {
      case '러닝':
      case '자전거':
        return 'distance';
      case '걷기':
        return 'steps';
      case '웨이트':
        return 'weight';
      default:
        return null;
    }
  }

  /// 저장 시 요약 문구(토스트용).
  String get _summary {
    final String base;
    switch (_metricKind) {
      case 'distance':
        base = '$_type ${_distanceKm.toStringAsFixed(1)}km · $_minutes분';
      case 'steps':
        base = '$_type ${_steps.toString()}보 · $_minutes분';
      case 'weight':
        base = '$_type ${_bodyParts[_bodyPart]} $_sets세트 · $_minutes분';
      default:
        base = '$_type $_minutes분';
    }
    return base;
  }

  /// 서버에 운동 기록을 제출하고 화면 데이터를 일괄 갱신한다.
  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final api = ref.read(apiClientProvider);
    setState(() => _saving = true);

    try {
      final result = await api.createWorkout(
        sport: _sportApi[_type] ?? 'etc',
        durationSec: _minutes * 60,
        distanceM:
            _metricKind == 'distance' ? (_distanceKm * 1000).round() : null,
        steps: _metricKind == 'steps' ? _steps : null,
        bodyPart: _metricKind == 'weight' ? _bodyApi[_bodyParts[_bodyPart]] : null,
        sets: _metricKind == 'weight' ? _sets : null,
        hasPhoto: _photoAttached,
      );
      invalidateAfterWorkout(ref);
      navigator.pop();
      OunToast.showWith(
        messenger,
        result.verified
            ? '$_summary 기록 · +${result.reward} 코인'
            : '$_summary 기록했지만 인증되지 않았어요',
        kind: result.verified ? OunToastKind.success : OunToastKind.info,
        icon: result.verified ? Icons.paid_rounded : null,
      );
    } catch (_) {
      navigator.pop();
      OunToast.showWith(messenger, '기록 저장에 실패했어요. 서버 연결을 확인해 주세요',
          kind: OunToastKind.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: OunColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 그랩 핸들
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: OunColors.cardBorder,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('운동 기록하기',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OunColors.textPrimary)),
              const SizedBox(height: 16),
              const _FieldLabel('종목'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _types.length; i++)
                    _TypeChip(
                      icon: _types[i].$2,
                      label: _types[i].$1,
                      selected: i == _selected,
                      onTap: () => setState(() => _selected = i),
                    ),
                ],
              ),
              // 종목별 지표(거리/걸음/부위·세트)
              ..._metricFields(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const _FieldLabel('시간'),
                  const Spacer(),
                  Text('$_minutes분',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: OunColors.textPrimary)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: OunColors.tabAccent,
                  inactiveTrackColor: OunColors.card,
                  thumbColor: OunColors.tabAccent,
                  overlayColor: OunColors.tabAccent.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: _minutes.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  onChanged: (v) => setState(() => _minutes = v.round()),
                ),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('운동 사진 (선택)'),
              const SizedBox(height: 8),
              _photoSection(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OunColors.tabAccent,
                    foregroundColor: OunColors.onTabAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: OunColors.onTabAccent))
                      : const Text('저장하기',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 선택 종목에 따라 달라지는 입력 필드들.
  List<Widget> _metricFields() {
    switch (_metricKind) {
      case 'distance':
        return [
          const SizedBox(height: 20),
          const _FieldLabel('거리'),
          const SizedBox(height: 8),
          _Stepper(
            valueText: '${_distanceKm.toStringAsFixed(1)} km',
            onMinus: () => setState(
                () => _distanceKm = (_distanceKm - 0.5).clamp(0.5, 99.0)),
            onPlus: () => setState(
                () => _distanceKm = (_distanceKm + 0.5).clamp(0.5, 99.0)),
          ),
        ];
      case 'steps':
        return [
          const SizedBox(height: 20),
          const _FieldLabel('걸음 수'),
          const SizedBox(height: 8),
          _Stepper(
            valueText: '$_steps 보',
            onMinus: () =>
                setState(() => _steps = (_steps - 500).clamp(0, 100000)),
            onPlus: () =>
                setState(() => _steps = (_steps + 500).clamp(0, 100000)),
          ),
        ];
      case 'weight':
        return [
          const SizedBox(height: 20),
          const _FieldLabel('부위'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _bodyParts.length; i++)
                _TypeChip(
                  icon: Icons.circle,
                  label: _bodyParts[i],
                  selected: i == _bodyPart,
                  onTap: () => setState(() => _bodyPart = i),
                  showIcon: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('세트'),
          const SizedBox(height: 8),
          _Stepper(
            valueText: '$_sets 세트',
            onMinus: () => setState(() => _sets = (_sets - 1).clamp(1, 30)),
            onPlus: () => setState(() => _sets = (_sets + 1).clamp(1, 30)),
          ),
        ];
      default:
        return const [];
    }
  }

  /// 운동 인증 사진 영역. 첨부 전/후 상태가 다르다.
  /// image_picker 연동 시 이 부분만 교체하면 된다.
  Widget _photoSection() {
    if (_photoAttached) {
      return Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: OunColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OunColors.cardBorder),
            ),
            child: const Icon(Icons.image_rounded,
                size: 26, color: OunColors.tabAccent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('사진이 첨부되었어요',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OunColors.textPrimary)),
          ),
          IconButton(
            onPressed: () => setState(() => _photoAttached = false),
            icon: const Icon(Icons.close_rounded,
                size: 20, color: OunColors.textMuted),
            tooltip: '사진 제거',
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _PhotoOption(
            icon: Icons.photo_camera_outlined,
            label: '촬영',
            onTap: () => setState(() => _photoAttached = true),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _PhotoOption(
            icon: Icons.photo_library_outlined,
            label: '앨범',
            onTap: () => setState(() => _photoAttached = true),
          ),
        ),
      ],
    );
  }
}

/// 사진 소스(촬영/앨범) 선택 버튼.
class _PhotoOption extends StatelessWidget {
  const _PhotoOption(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: OunColors.tabAccent),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: OunColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시트 안 작은 섹션 라벨.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, color: OunColors.textMuted));
}

/// – 값 + 형태의 숫자 스테퍼.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
  });
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        children: [
          _btn(Icons.remove_rounded, onMinus),
          Expanded(
            child: Text(valueText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
          ),
          _btn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 52,
            height: 48,
            child: Icon(icon, size: 20, color: OunColors.tabAccent),
          ),
        ),
      );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showIcon = true,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? OunColors.tabAccent : OunColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: selected ? OunColors.tabAccent : OunColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(icon,
                  size: 16,
                  color:
                      selected ? OunColors.onTabAccent : OunColors.tabAccent),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? OunColors.onTabAccent
                        : OunColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
