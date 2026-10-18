import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../character/character_avatar.dart';

/// 월말 감성 리포트: 한 달을 숫자 줄 세우기 대신 "나는 이렇게 움직였다" 카드로.
/// 카드는 그대로 이미지로 떠서 SNS에 공유할 수 있다.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _cardKey = GlobalKey();
  late String _month = _monthKey(DateTime.now());
  bool _sharing = false;

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String _shift(String month, int delta) {
    final y = int.parse(month.substring(0, 4));
    final m = int.parse(month.substring(5, 7));
    return _monthKey(DateTime(y, m + delta));
  }

  Future<void> _share(MonthlyReport report) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png!.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'oun_${report.month}.png',
            ),
          ],
          fileNameOverrides: ['oun_${report.month}.png'],
          text: '${_monthTitle(report.month)}의 오운 리포트',
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      OunToast.showWith(messenger, '이미지를 만들지 못했어요');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(monthlyReportProvider(_month));
    final report = async.value;
    final canPrev = report != null && _month.compareTo(report.firstMonth) > 0;
    final canNext = report != null && !report.isCurrentMonth;

    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('월말 리포트',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
        children: [
          // 달 넘기기
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: canPrev
                    ? () => setState(() => _month = _shift(_month, -1))
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                color: OunColors.textPrimary,
              ),
              Text(_monthTitle(_month),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: OunColors.textPrimary)),
              IconButton(
                onPressed: canNext
                    ? () => setState(() => _month = _shift(_month, 1))
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: OunColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          async.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(
                  child: CircularProgressIndicator(color: OunColors.tabAccent)),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(
                child: Text('리포트를 불러오지 못했어요',
                    style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
              ),
            ),
            data: (r) => Column(
              children: [
                RepaintBoundary(
                  key: _cardKey,
                  child: _ReportCard(report: r),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: OunColors.tabAccent,
                      foregroundColor: OunColors.onTabAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _sharing ? null : () => _share(r),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('이미지로 공유하기',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _monthTitle(String month) =>
    '${month.substring(0, 4)}년 ${int.parse(month.substring(5, 7))}월';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
const _timeLabels = {
  'morning': '아침',
  'afternoon': '낮',
  'evening': '저녁',
  'night': '밤',
};

/// 종목 → 칭호에 들어갈 동사.
const _sportVerbs = {
  'running': '달리는',
  'walking': '산책하는',
  'weight': '힘을 기르는',
  'cycling': '바람을 가르는',
  'yoga': '마음을 고르는',
  'etc': '몸을 깨우는',
};

/// 리포트 칭호와 한마디. 줄 세우지 않고, 쉰 달도 탓하지 않는다.
(String, String) reportHeadline(MonthlyReport r) {
  if (r.workoutDays == 0) {
    return r.isCurrentMonth
        ? ('이제 막 시작하는 오운이', '이번 달 첫 기록을 기다리고 있어요')
        : ('푹 쉬어 간 오운이', '쉬는 달도 괜찮아요. 다시 가볍게 시작해 봐요');
  }
  final verb = _sportVerbs[r.bySport.first.sport] ?? '몸을 깨우는';
  final how = r.workoutDays >= 20
      ? '매일같이'
      : r.workoutDays >= 12
          ? '꾸준히'
          : r.workoutDays >= 5
              ? '차곡차곡'
              : '천천히';
  final more = r.workoutDays - r.prevWorkoutDays;
  final line = r.prevWorkoutDays > 0 && more > 0
      ? '지난달보다 $more일 더 움직였어요!'
      : r.longestStreak >= 3
          ? '${r.longestStreak}일 연속으로 이어 간 날도 있었어요'
          : '나만의 속도로 차곡차곡 쌓았어요';
  return ('$how $verb 오운이', line);
}

/// 목적격 조사: 받침이 있으면 '을', 없으면 '를'. (러닝을, 걷기를)
String _object(String word) {
  final c = word.codeUnitAt(word.length - 1);
  final hasBatchim = c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0;
  return '$word${hasBatchim ? '을' : '를'}';
}

String _duration(int minutes) {
  if (minutes < 60) return '$minutes분';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h시간' : '$h시간 $m분';
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = report;
    final (title, line) = reportHeadline(r);
    final look = CharacterLook(
      gender: ref.watch(authProvider.select((a) => a.profile?.gender)) ?? 'f',
      equipment: ref.watch(equippedItemsProvider).value ?? const {},
    );

    final facts = <(IconData, String)>[
      if (r.bySport.isNotEmpty)
        (
          sportIcons[r.bySport.first.sport] ?? Icons.sports_gymnastics,
          '${_object(sportLabels[r.bySport.first.sport] ?? '운동')} 가장 많이 했어요 · '
              '${r.bySport.first.count}회',
        ),
      if (r.topWeekday != null && r.topTimeOfDay != null)
        (
          Icons.schedule_rounded,
          '주로 ${_weekdays[r.topWeekday!]}요일 ${_timeLabels[r.topTimeOfDay] ?? ''}에 움직였어요',
        ),
      if (r.totalDistanceM >= 100)
        (
          Icons.route_rounded,
          '모두 ${(r.totalDistanceM / 1000).toStringAsFixed(1)}km를 움직였어요',
        ),
      if (r.cheersReceived > 0)
        (Icons.favorite_rounded, '응원을 ${r.cheersReceived}번 받았어요'),
      if (r.restDays + r.protectedDays > 0)
        (
          Icons.bedtime_rounded,
          '쉬어 간 날 ${r.restDays + r.protectedDays}일 · 그래도 기록은 이어졌어요',
        ),
      if (r.coinsEarned > 0)
        (Icons.monetization_on_rounded, '코인 ${comma(r.coinsEarned)}개를 모았어요'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OunColors.cardBorder),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF1E2), Color(0xFFFFFDFB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_monthTitle(r.month)}의 나',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OunColors.tabAccent)),
                    const SizedBox(height: 6),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 21,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: OunColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(line,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: OunColors.textMuted)),
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                child: CharacterFigure(
                  look: look,
                  face: r.workoutDays == 0
                      ? CharacterFace.sleepy
                      : CharacterFace.happy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _BigStat(value: '${r.workoutDays}일', label: '운동한 날'),
              _BigStat(value: _duration(r.totalMinutes), label: '함께한 시간'),
              _BigStat(value: '${r.longestStreak}일', label: '최장 연속'),
            ],
          ),
          const SizedBox(height: 16),
          _MonthDots(report: r),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final (icon, text) in facts)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: OunColors.tabAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(text,
                          style: const TextStyle(
                              fontSize: 12.5, color: OunColors.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          const Center(
            child: Text('오운 · 오늘의 운동, 나만의 속도로',
                style: TextStyle(fontSize: 10.5, color: OunColors.textFaint)),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: OunColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: OunColors.textPrimary)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 10.5, color: OunColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// 한 달 달력 점: 운동한 날은 채운 점, 나머지는 빈 점. 월요일 시작.
class _MonthDots extends StatelessWidget {
  const _MonthDots({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final y = int.parse(report.month.substring(0, 4));
    final m = int.parse(report.month.substring(5, 7));
    final lead = DateTime(y, m, 1).weekday - 1; // 월=0
    final cells = lead + report.daysInMonth;
    final rows = (cells / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(w,
                      style: const TextStyle(
                          fontSize: 10, color: OunColors.textFaint)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: Center(child: _dot(row * 7 + col - lead + 1))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(int day) {
    if (day < 1 || day > report.daysInMonth) {
      return const SizedBox(width: 14, height: 14);
    }
    final active = report.activeDates.contains(day);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? OunColors.tabAccent : OunColors.card,
      ),
    );
  }
}
