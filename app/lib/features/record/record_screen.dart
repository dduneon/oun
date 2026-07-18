import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';

/// 운동 기록·입력. 주간 스트릭 + 종목 퀵스타트 + 최근 기록.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '기록',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: OunColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: const Text('7월',
            style: TextStyle(
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
        const _SectionHeader('최근 기록'),
        const _RecordRow(Icons.directions_run, '러닝', '오늘 · 5.2km', '32분'),
        const _RecordRow(Icons.fitness_center, '웨이트', '어제 · 상체', '45분'),
        const _RecordRow(Icons.directions_walk, '걷기', '2일 전 · 8,200보', '58분'),
      ],
    );
  }

  void _openSheet(BuildContext context, String? preset, IconData? icon) {
    showModalBottomSheet<void>(
      context: context,
      // 루트 네비게이터에 띄워야 플로팅 탭바 위로 올라온다.
      // (기본값은 브랜치 네비게이터라 탭바에 가려짐)
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordInputSheet(preset: preset, presetIcon: icon),
    );
  }

}

/// 주간 스트릭 + 펼치면 월간 도트 캘린더(날짜 + 운동량 점) + 월 요약.
/// 평소엔 주간만 보여 공간을 아끼고, '월간 보기'로 펼친다.
class _MonthSection extends StatefulWidget {
  const _MonthSection();

  @override
  State<_MonthSection> createState() => _MonthSectionState();
}

class _MonthSectionState extends State<_MonthSection> {
  bool _expanded = false;

  // 목데이터 (실제로는 일별 운동 시간 합계로 강도 계산)
  static const _weekLabels = ['월', '화', '수', '목', '금', '토', '일'];
  static const _todayWeekIndex = 4; // 이번 주 금요일
  static const _daysInMonth = 31;
  static const _leadingEmpty = 1; // 7/1 = 화 (월요일 시작 기준 빈칸 1)
  static const _todayDay = 18;
  // 31일 운동 강도 0(안 함)~4(많이)
  static const _intensity = <int>[
    0, 2, 1, 0, 3, 4, 2, //
    1, 0, 2, 3, 3, 4, 0, //
    2, 1, 0, 4, 3, 2, 1, //
    0, 3, 4, 2, 1, 3, 2, //
    1, 0, 4,
  ];
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
                  done: i <= _todayWeekIndex,
                  isToday: i == _todayWeekIndex,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 12, color: OunColors.textMuted),
              children: [
                TextSpan(text: '이번 주 '),
                TextSpan(
                    text: '5일',
                    style: TextStyle(
                        color: OunColors.tabAccent,
                        fontWeight: FontWeight.w700)),
                TextSpan(text: ' 운동 · 연속 12일'),
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
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('2025년 7월',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
            const Spacer(),
            _navArrow(Icons.chevron_left_rounded),
            const SizedBox(width: 6),
            _navArrow(Icons.chevron_right_rounded),
          ],
        ),
        const SizedBox(height: 12),
        // 월 요약
        Row(
          children: const [
            Expanded(child: _MonthStat(value: '18', label: '운동한 날')),
            _StatSep(),
            Expanded(child: _MonthStat(value: '9.2h', label: '총 시간')),
            _StatSep(),
            Expanded(child: _MonthStat(value: '12일', label: '최장 연속')),
          ],
        ),
        const SizedBox(height: 14),
        _calendarGrid(),
      ],
    );
  }

  Widget _navArrow(IconData icon) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: OunColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: OunColors.tabAccent),
      );

  Widget _calendarGrid() {
    final weeks = <Widget>[];
    var day = 1 - _leadingEmpty;
    final total = _leadingEmpty + _daysInMonth;
    final weekCount = (total / 7).ceil();
    for (var w = 0; w < weekCount; w++) {
      final row = <Widget>[];
      for (var i = 0; i < 7; i++) {
        row.add(Expanded(
          child: (day < 1 || day > _daysInMonth)
              ? const SizedBox(height: 38)
              : _dayCell(day),
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

  Widget _dayCell(int d) {
    final v = _intensity[d - 1];
    final isToday = d == _todayDay;
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
              color: v > 0 ? _heat[v] : Colors.transparent,
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
                onTap: () {}, // TODO: 전체 기록 목록
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

/// 운동 기록 입력 바텀시트. 종목 선택 + 시간(분) + 강도 메모.
/// 목업이라 저장은 스낵바로 확인만 하고 닫는다.
class _RecordInputSheet extends StatefulWidget {
  const _RecordInputSheet({this.preset, this.presetIcon});
  final String? preset;
  final IconData? presetIcon;

  @override
  State<_RecordInputSheet> createState() => _RecordInputSheetState();
}

class _RecordInputSheetState extends State<_RecordInputSheet> {
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

  /// 저장 시 요약 문구(토스트용). 지표 + 시간 (+ 사진 인증).
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
    return _photoAttached ? '$base · 사진 인증' : base;
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
                onPressed: () {
                  // pop 이후 context가 분리되므로 messenger를 먼저 확보한다.
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  OunToast.showWith(
                    messenger,
                    '$_summary 기록했어요',
                    kind: OunToastKind.success,
                  );
                },
                child: const Text('저장하기',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
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
  /// 목업이라 실제 이미지는 없고, image_picker 연동 시 이 부분만 교체하면 된다.
  Widget _photoSection() {
    if (_photoAttached) {
      return Row(
        children: [
          // 첨부된 사진 썸네일(자리표시)
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
    // 첨부 전: 촬영/앨범을 모달 없이 시트 안에서 바로 고른다.
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
