import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';

/// 운동 기록·입력. 주간 스트릭 + 종목 퀵스타트 + 최근 기록.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  static const _week = ['월', '화', '수', '목', '금', '토', '일'];
  static const _todayIndex = 4; // 목업: 오늘을 금요일로 가정

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
        _card(
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    _DayDot(
                      label: _week[i],
                      done: i <= _todayIndex,
                      isToday: i == _todayIndex,
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
            ],
          ),
        ),
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

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OunColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: child,
      );
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

  late int _selected;
  int _minutes = 30;

  @override
  void initState() {
    super.initState();
    final i = _types.indexWhere((t) => t.$1 == widget.preset);
    _selected = i < 0 ? 0 : i;
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
            const Text('종목',
                style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
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
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('시간',
                    style:
                        TextStyle(fontSize: 12, color: OunColors.textMuted)),
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
            const SizedBox(height: 8),
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
                  final name = _types[_selected].$1;
                  // pop 이후 context가 분리되므로 messenger를 먼저 확보한다.
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  OunToast.showWith(
                    messenger,
                    '$name $_minutes분 기록했어요',
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
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
            Icon(icon,
                size: 16,
                color:
                    selected ? OunColors.onTabAccent : OunColors.tabAccent),
            const SizedBox(width: 6),
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
