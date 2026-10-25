import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';
import '../record/workout_editor.dart';
import 'health_workout.dart';

Future<void> openHealthImport(
  BuildContext context, {
  bool onlyUnrecorded = false,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => HealthImportScreen(onlyUnrecorded: onlyUnrecorded),
  ),
);

class HealthImportScreen extends ConsumerStatefulWidget {
  const HealthImportScreen({
    super.key,
    this.health,
    this.onlyUnrecorded = false,
  });
  final bool onlyUnrecorded;
  final HealthWorkouts? health;
  @override
  ConsumerState<HealthImportScreen> createState() => _HealthImportScreenState();
}

class _HealthImportScreenState extends ConsumerState<HealthImportScreen>
    with WidgetsBindingObserver {
  late final _health = widget.health ?? HealthWorkouts();
  Map<String, String> _saved = {};
  List<HealthWorkout> _items = [];
  bool _busy = false, _loaded = false, _unavailable = false;
  String? _error;
  bool _needsAuthorization = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load({bool request = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _items = [];
      _loaded = false;
    });
    try {
      final available = await _health.available();
      if (!mounted) return;
      setState(() => _unavailable = !available);
      if (!available) return;
      final needsAuthorization = await _health.needsAuthorization();
      if (!mounted) return;
      setState(() => _needsAuthorization = needsAuthorization);
      if (needsAuthorization) {
        if (!request) return;
        await _health.authorize();
        if (!mounted) return;
        final stillNeeded = await _health.needsAuthorization();
        if (!mounted) return;
        setState(() => _needsAuthorization = stillNeeded);
        if (stillNeeded) {
          setState(() => _error = '운동 읽기를 허용하면 최근 운동을 볼 수 있어요.');
          return;
        }
      }
      final items = await _health.readRecent();
      if (!mounted) return;
      final saved = await ref.refresh(healthImportStatesProvider.future);
      if (mounted) {
        setState(() {
          _items = widget.onlyUnrecorded
              ? items.where((w) => !saved.containsKey(w.importKey)).toList()
              : items;
          _saved = saved;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = '운동을 불러오지 못했어요. 건강 앱의 읽기 권한과 동기화를 확인한 뒤 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(HealthWorkout workout) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkoutEditor(imported: workout),
    );
    if (saved == true && mounted) {
      setState(() => _saved[workout.importKey] = 'recorded');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHealthConnect = HealthWorkouts.name == 'Health Connect';
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: Text(
          widget.onlyUnrecorded ? '아직 기록하지 않은 운동' : '건강 앱에서 불러오기',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: OunColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          const _Intro(),
          const SizedBox(height: 14),
          if (_busy)
            const _Loading()
          else if (_needsAuthorization && !_unavailable)
            _ConnectCard(onConnect: () => _load(request: true)),
          if (_unavailable)
            _Notice(
              icon: Icons.phonelink_erase_rounded,
              text:
                  '이 기기에서 건강 앱을 사용할 수 없어요. Android 9 이상에서는 Health Connect 설치 또는 업데이트를 확인해 주세요.',
              action: HealthWorkouts.supported && isHealthConnect
                  ? _SoftButton(
                      label: 'Health Connect 설치 / 업데이트',
                      icon: Icons.download_rounded,
                      onPressed: _health.install,
                    )
                  : null,
            ),
          if (_error != null)
            _Notice(icon: Icons.info_outline_rounded, text: _error!),
          if (!_busy && _loaded && _items.isEmpty)
            _Empty(
              tip: isHealthConnect
                  ? '삼성 헬스 → 설정 → Health Connect에서 운동 공유를 확인해 주세요. 워치 기록은 휴대폰에 동기화된 뒤 표시돼요.'
                  : null,
            ),
          if (_loaded && _items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 9),
              child: Text(
                '최근 운동 ${_items.length}개',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary,
                ),
              ),
            ),
            for (final workout in _items)
              _WorkoutRow(
                workout: workout,
                state: _saved[workout.importKey],
                onTap: () => _select(workout),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                '소요 시간은 시작부터 종료까지예요. 휴식 시간이 포함되어 있다면 저장 전에 수정해 주세요. 6시간을 넘는 운동은 현재 불러올 수 없어요.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: OunColors.textFaint,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (!_busy && (_loaded || _error != null))
            Center(
              child: _SoftButton(
                label: '새로고침',
                icon: Icons.refresh_rounded,
                onPressed: () => _load(),
              ),
            ),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: OunColors.textMuted),
              onPressed: _busy ? null : () => _showDataInfo(context),
              child: const Text(
                '연결 및 데이터 관리',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: OunColors.textFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상단 안내: 어느 건강 앱에서, 어떤 범위를 불러오는지.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OunColors.card,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: OunColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.favorite_rounded,
            size: 21,
            color: OunColors.tabAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${HealthWorkouts.name}의 최근 운동',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: OunColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '최근 30일의 운동 중 기록할 운동을 골라 주세요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: OunColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: OunColors.tabAccent,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '최근 운동을 불러오고 있어요',
          style: TextStyle(fontSize: 12, color: OunColors.textMuted),
        ),
      ],
    ),
  );
}

/// 첫 연결: 무엇을 읽고 무엇을 보관하는지 먼저 알려 주고 권한을 요청한다.
class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OunColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: OunColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '날짜와 시간을 직접 입력하지 않아도 돼요',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: OunColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final (icon, text) in const [
          (Icons.directions_run_rounded, '운동 종류·시간·거리·칼로리를 읽어 목록을 보여드려요.'),
          (Icons.cloud_done_outlined, '저장을 누른 운동만 오운 서버에 보관해요.'),
          (Icons.lock_outline_rounded, '건강 앱의 원본 기록은 변경하지 않아요.'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: OunColors.tabAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: OunColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: OunColors.tabAccent,
              foregroundColor: OunColors.onTabAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onConnect,
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: Text(
              '${HealthWorkouts.name} 연결하기',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 기록 탭의 기록 행과 같은 톤. 이미 저장/삭제한 운동은 상태 칩으로 표시하고 누를 수 없다.
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.workout,
    required this.state,
    required this.onTap,
  });
  final HealthWorkout workout;
  final String? state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = state != null;
    final start = workout.start;
    final time = '${start.hour}:${start.minute.toString().padLeft(2, '0')}';
    final distance = workout.distanceM == null
        ? ''
        : ' · ${(workout.distanceM! / 1000).toStringAsFixed(2)}km';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: done ? OunColors.background : OunColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: OunColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: done ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                    sportIcons[workout.sport] ?? Icons.sports_gymnastics,
                    size: 19,
                    color: done ? OunColors.textFaint : OunColors.tabAccent,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sportLabels[workout.sport] ?? '기타'} · ${workout.durationSec ~/ 60}분',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: done
                              ? OunColors.textMuted
                              : OunColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${start.month}월 ${start.day}일 $time$distance',
                        style: const TextStyle(
                          fontSize: 11,
                          color: OunColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (done)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: OunColors.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      state == 'deleted' ? '삭제한 기록' : '기록 완료',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: OunColors.textMuted,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: OunColors.textFaint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 안내/오류 카드. 경고색 대신 차분한 톤으로 다음 행동을 알려 준다.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: OunColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: OunColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: OunColors.tabAccent),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: OunColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 10), action!],
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({this.tip});
  final String? tip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: OunColors.card,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.directions_run_rounded,
            size: 26,
            color: OunColors.textFaint,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '불러올 운동이 없어요',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: OunColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '최근 30일의 운동 기록, 읽기 권한, 건강 앱 동기화를 확인해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: OunColors.textMuted,
          ),
        ),
        if (tip != null) ...[
          const SizedBox(height: 10),
          Text(
            tip!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: OunColors.textFaint,
            ),
          ),
        ],
      ],
    ),
  );
}

/// 보조 동작용 작은 테두리 버튼.
class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: OunColors.tabAccent,
      backgroundColor: OunColors.surface,
      side: const BorderSide(color: OunColors.cardBorder),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
    label: Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

/// 권한 변경·데이터 보관 안내. 다른 확인 시트와 같은 바텀시트 톤.
void _showDataInfo(BuildContext context) {
  const sections = [
    ('아이폰', '건강 앱 → 프로필 → 앱 → 오운에서 읽기 권한을 변경할 수 있어요.'),
    ('안드로이드', '설정 → Health Connect → 앱 권한 → 오운에서 권한을 변경할 수 있어요.'),
    (
      '저장한 기록',
      '권한을 해제해도 저장한 오운 기록은 남아요. 기록 상세에서 삭제할 수 있으며, 중복 지급 방지를 위해 원본 기록 식별자는 회원 탈퇴까지 보관해요. 삭제한 운동은 다시 불러올 수 없어요.',
    ),
  ];
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      decoration: const BoxDecoration(
        color: OunColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: OunColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              '연결 및 데이터 관리',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OunColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            for (final (title, body) in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: OunColors.tabAccent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: OunColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OunColors.tabAccent,
                  foregroundColor: OunColors.onTabAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(sheet),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
