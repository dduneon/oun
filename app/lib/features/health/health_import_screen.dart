import 'package:flutter/material.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';
import '../record/workout_editor.dart';
import 'health_workout.dart';

void openHealthImport(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const HealthImportScreen()));

class HealthImportScreen extends StatefulWidget {
  const HealthImportScreen({super.key, this.health});
  final HealthWorkouts? health;
  @override
  State<HealthImportScreen> createState() => _HealthImportScreenState();
}

class _HealthImportScreenState extends State<HealthImportScreen>
    with WidgetsBindingObserver {
  late final _health = widget.health ?? HealthWorkouts();
  final Set<String> _saved = {};
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
      if (mounted) {
        setState(() {
          _items = items;
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
    if (saved == true && mounted) setState(() => _saved.add(workout.id));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OunColors.background,
    appBar: AppBar(
      title: const Text('건강 앱에서 불러오기'),
      backgroundColor: OunColors.background,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${HealthWorkouts.name}의 최근 운동',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('최근 30일의 운동 중 기록할 운동을 선택해 주세요.'),
        const SizedBox(height: 16),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('최근 운동을 불러오고 있어요'),
              ],
            ),
          )
        else if (_needsAuthorization && !_unavailable) ...[
          const Text('건강 앱을 연결하면 운동 날짜와 시간을 직접 입력하지 않아도 돼요.'),
          const SizedBox(height: 12),
          const Text(
            '운동·거리·칼로리를 읽어 목록을 보여드려요. 저장을 누른 운동만 오운 서버에 보관하고, 건강 앱의 원본은 변경하지 않아요.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _load(request: true),
            icon: const Icon(Icons.favorite_outline),
            label: Text('${HealthWorkouts.name} 연결하기'),
          ),
        ],
        if (_unavailable) ...[
          const Text(
            '이 기기에서 건강 앱을 사용할 수 없어요. Android 9 이상에서는 Health Connect 설치 또는 업데이트를 확인해 주세요.',
          ),
          if (HealthWorkouts.supported &&
              HealthWorkouts.name == 'Health Connect')
            TextButton(
              onPressed: _health.install,
              child: const Text('Health Connect 설치 / 업데이트'),
            ),
        ],
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (!_busy && _loaded && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '불러올 운동이 없어요. 최근 30일의 운동 기록, 읽기 권한, 건강 앱 동기화를 확인해 주세요.',
            ),
          ),
        if (_loaded && _items.isNotEmpty)
          const Text(
            '소요 시간은 시작부터 종료까지예요. 휴식 시간이 포함되어 있다면 저장 전에 수정해 주세요. 6시간을 넘는 운동은 현재 불러올 수 없어요.',
            style: TextStyle(fontSize: 12, color: OunColors.textMuted),
          ),
        for (final workout in _items)
          Card(
            child: ListTile(
              leading: Icon(sportIcons[workout.sport] ?? Icons.fitness_center),
              title: Text(
                '${sportLabels[workout.sport] ?? '기타'} · ${workout.durationSec ~/ 60}분',
              ),
              subtitle: Text(
                '${workout.start.month}월 ${workout.start.day}일 ${workout.start.hour}:${workout.start.minute.toString().padLeft(2, '0')}'
                '${workout.distanceM == null ? '' : ' · ${(workout.distanceM! / 1000).toStringAsFixed(2)} km'}',
              ),
              trailing: _saved.contains(workout.id)
                  ? const Text('저장됨')
                  : const Icon(Icons.chevron_right),
              onTap: _saved.contains(workout.id)
                  ? null
                  : () => _select(workout),
            ),
          ),
        if (!_busy && (_loaded || _error != null))
          TextButton.icon(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
          ),
        if (!_busy &&
            _loaded &&
            _items.isEmpty &&
            HealthWorkouts.name == 'Health Connect')
          const Text(
            '삼성 헬스 → 설정 → Health Connect에서 운동 공유를 확인해 주세요. 워치 기록은 휴대폰에 동기화된 뒤 표시돼요.',
          ),
        TextButton(
          onPressed: _busy
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('연결 및 데이터 관리'),
                    content: const Text(
                      '아이폰: 건강 앱 → 프로필 → 앱 → 오운에서 읽기 권한을 변경할 수 있어요.\n\n안드로이드: 설정 → Health Connect → 앱 권한 → 오운에서 권한을 변경할 수 있어요.\n\n권한을 해제해도 저장한 오운 기록은 남아요. 기록 상세에서 삭제할 수 있으며, 중복 지급 방지를 위해 원본 기록 식별자는 회원 탈퇴까지 보관해요. 삭제한 운동은 다시 불러올 수 없어요.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                ),
          child: const Text('연결 및 데이터 관리'),
        ),
      ],
    ),
  );
}
