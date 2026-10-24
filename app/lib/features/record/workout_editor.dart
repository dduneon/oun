import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../health/health_workout.dart';

class WorkoutEditor extends ConsumerStatefulWidget {
  const WorkoutEditor({
    super.key,
    this.preset,
    this.imported,
    this.editing,
    this.repeat = false,
  });
  final String? preset;
  final HealthWorkout? imported;
  final Workout? editing;
  final bool repeat;
  @override
  ConsumerState<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends ConsumerState<WorkoutEditor> {
  final _form = GlobalKey<FormState>();
  final _minutes = TextEditingController(text: '30');
  final _seconds = TextEditingController(text: '0');
  final _distance = TextEditingController();
  final _steps = TextEditingController();
  final _sets = TextEditingController(text: '3');
  final _calories = TextEditingController();
  final _note = TextEditingController();
  final _name = TextEditingController();
  final List<_ExerciseDraft> _exercises = [];
  String _sport = 'running';
  String _body = 'upper';
  DateTime _date = DateTime.now();
  int? _effort;
  bool _saving = false;
  bool _showDetails = false;
  // 시트 안에 보여줄 오류. 토스트는 시트 뒤 화면에 떠서 가려진다.
  String? _error;
  XFile? _photo;
  bool get _healthDefaults =>
      widget.imported != null ||
      widget.editing?.source == 'healthkit' ||
      widget.editing?.source == 'health_connect';
  bool get _editing => widget.editing != null && !widget.repeat;

  @override
  void initState() {
    super.initState();
    _sport =
        sportLabels.entries
            .where((e) => e.value == widget.preset)
            .firstOrNull
            ?.key ??
        'running';
    final w = widget.editing;
    if (w != null) {
      _sport = w.sport;
      _minutes.text = '${w.durationSec ~/ 60}';
      _seconds.text = '${w.durationSec % 60}';
      _distance.text = w.distanceM == null ? '' : '${w.distanceM! / 1000}';
      _steps.text = w.steps?.toString() ?? '';
      _sets.text = w.sets?.toString() ?? (_healthDefaults ? '' : '3');
      _body = w.bodyPart ?? (_healthDefaults ? '' : 'upper');
      _name.text = w.customSportName ?? '';
      _exercises.addAll(w.exercises.map(_ExerciseDraft.fromWorkout));
      if (!widget.repeat) {
        _date = w.performedAt;
        _calories.text = w.calories?.toString() ?? '';
        _note.text = w.note ?? '';
        _effort = w.effort;
      }
    }
    final imported = widget.imported;
    if (imported != null) {
      _sport = imported.sport;
      _date = imported.start;
      _minutes.text = '${imported.durationSec ~/ 60}';
      _seconds.text = '${imported.durationSec % 60}';
      _distance.text = (imported.distanceM ?? 0) <= 0
          ? ''
          : '${imported.distanceM! / 1000}';
      _calories.text = imported.calories?.toString() ?? '';
      // No set count or body-part information is provided by these sources.
      _sets.text = '';
      _body = '';
    }
    _showDetails =
        _note.text.isNotEmpty || _effort != null || _calories.text.isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in [
      _minutes,
      _seconds,
      _distance,
      _steps,
      _sets,
      _calories,
      _note,
      _name,
    ]) {
      c.dispose();
    }
    for (final e in _exercises) {
      e.dispose();
    }
    super.dispose();
  }

  /// 오운 톤 숫자 입력칸(밝은 카드 + 둥근 테두리 + 단위 접미사).
  Widget _number(
    TextEditingController c, {
    Key? key,
    String? hint,
    String? suffix,
    bool optional = false,
    bool decimal = false,
    double min = 0,
    double max = 100000,
  }) => TextFormField(
    key: key,
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    textAlign: TextAlign.center,
    cursorColor: OunColors.tabAccent,
    style: _inputStyle,
    decoration: _ounInput(hint: hint, suffix: suffix),
    onChanged: (_) => setState(() {}),
    validator: (value) {
      if (optional && (value ?? '').trim().isEmpty) return null;
      final n = double.tryParse(value ?? '');
      if (n == null ||
          !n.isFinite ||
          n < min ||
          n > max ||
          (!decimal && int.tryParse(value ?? '') == null)) {
        return '${_trim(min)}~${_trim(max)} 사이${decimal ? '' : ' 정수'}로 입력해 주세요';
      }
      return null;
    },
  );

  /// 운동한 날짜·시간을 iOS 휠 피커 시트로 고른다.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    var picked = _date.isAfter(now) ? now : _date;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: OunColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _GrabHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '언제 운동했나요?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: OunColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: TextButton.styleFrom(
                        foregroundColor: OunColors.tabAccent,
                      ),
                      child: const Text(
                        '완료',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 19,
                        color: OunColors.textPrimary,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    initialDateTime: picked,
                    minimumDate: DateTime(2000),
                    maximumDate: now,
                    onDateTimeChanged: (d) => picked = d,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) setState(() => _date = picked);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      setState(() => _error = '입력값을 확인해 주세요');
      return;
    }
    final duration = int.parse(_minutes.text) * 60 + int.parse(_seconds.text);
    if (duration < 1 || duration > 21600) {
      setState(() => _error = '운동 시간은 1초부터 6시간까지 입력해 주세요');
      return;
    }
    if (_date.isAfter(DateTime.now())) {
      setState(() => _error = '미래의 운동은 기록할 수 없어요');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      String? photoRef;
      if (_photo != null) {
        photoRef = await api.uploadWorkoutPhoto(
          await _photo!.readAsBytes(),
          contentType: _photo!.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
        );
      }
      final exercises = _sport == 'weight'
          ? _exercises.map((e) => e.toWorkout()).toList()
          : <WorkoutExercise>[];
      final details = <String, dynamic>{
        'performedAt': _date.toUtc().toIso8601String(),
        if (widget.imported != null) ...{
          'source': widget.imported!.source,
          'externalId': widget.imported!.id,
        },
        'calories': int.tryParse(_calories.text),
        'note': _note.text.trim(),
        'effort': _effort,
        'customSportName': _sport == 'etc' || _sport == 'yoga'
            ? _name.text.trim()
            : '',
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
      final distance =
          ['running', 'cycling', 'walking'].contains(_sport) &&
              _distance.text.isNotEmpty
          ? (double.parse(_distance.text) * 1000).round()
          : null;
      final steps = _sport == 'walking' ? int.tryParse(_steps.text) : null;
      final sets = _sport == 'weight'
          ? (exercises.isEmpty
                ? int.tryParse(_sets.text)
                : exercises.fold<int>(0, (n, e) => n + e.sets.length))
          : null;
      final result = _editing
          ? await api.updateWorkout(
              widget.editing!.id,
              sport: _sport,
              durationSec: duration,
              distanceM: distance,
              steps: steps,
              bodyPart: _sport == 'weight' && _body.isNotEmpty ? _body : null,
              sets: exercises.isEmpty ? sets : null,
              photoRef: photoRef,
              details: details,
            )
          : await api.createWorkout(
              sport: _sport,
              durationSec: duration,
              distanceM: distance,
              steps: steps,
              bodyPart: _sport == 'weight' && _body.isNotEmpty ? _body : null,
              sets: exercises.isEmpty ? sets : null,
              photoRef: photoRef,
              details: details,
            );
      if (!mounted) return;
      invalidateAfterWorkout(ref);
      // 시트를 닫은 뒤 보이도록 messenger를 먼저 잡아 둔다.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      OunToast.showWith(
        messenger,
        result.verified
            ? (_editing
                  ? '운동 기록을 수정했어요'
                  : '운동 기록 완료 · +${result.reward} 코인'
                        '${result.protectorEarned ? ' · 기록 보호권 +1' : ''}')
            : '기록은 저장했지만 인증되지 않았어요',
      );
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = apiErrorMessage(e, '저장하지 못했어요. 입력 내용은 유지돼요. 다시 시도해 주세요'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = double.tryParse(_distance.text) ?? 0;
    final duration =
        (int.tryParse(_minutes.text) ?? 0) * 60 +
        (int.tryParse(_seconds.text) ?? 0);
    final pace = distance > 0 ? (duration / distance).round() : 0;
    final media = MediaQuery.of(context);
    return PopScope(
      canPop: !_saving,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * .92),
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          math.max(media.viewInsets.bottom, media.padding.bottom) + 16,
        ),
        decoration: const BoxDecoration(
          color: OunColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GrabHandle(),
              Text(
                _editing
                    ? '운동 수정'
                    : widget.repeat
                    ? '다시 기록하기'
                    : '운동 기록하기',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary,
                ),
              ),
              if (widget.imported != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '건강 앱에서 불러왔어요. 내용을 확인하고 저장해 주세요.',
                    style: TextStyle(fontSize: 12, color: OunColors.textMuted),
                  ),
                ),
              const SizedBox(height: 4),
              Flexible(
                child: AbsorbPointer(
                  absorbing: _saving,
                  child: Form(
                    key: _form,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(
                            '종목',
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final e in sportLabels.entries)
                                  _TypeChip(
                                    icon: sportIcons[e.key],
                                    label: e.value,
                                    selected: _sport == e.key,
                                    onTap: () => setState(() => _sport = e.key),
                                  ),
                              ],
                            ),
                          ),
                          _section(
                            '언제',
                            _SoftButton(
                              onTap: _pickDate,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                    color: OunColors.tabAccent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _dateLabel(_date),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: OunColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: OunColors.textFaint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_sport == 'etc' || _sport == 'yoga')
                            _section(
                              _sport == 'etc'
                                  ? '운동 이름 (선택)'
                                  : '요가 스타일 / 동작 (선택)',
                              TextFormField(
                                controller: _name,
                                maxLength: 80,
                                cursorColor: OunColors.tabAccent,
                                style: _inputStyle,
                                decoration: _ounInput(
                                  hint: _sport == 'etc' ? '예: 클라이밍' : '예: 빈야사',
                                ),
                              ),
                            ),
                          _section(
                            '운동 소요 시간',
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _number(
                                    _minutes,
                                    suffix: '분',
                                    max: 360,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _number(
                                    _seconds,
                                    suffix: '초',
                                    max: 59,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ([
                            'running',
                            'cycling',
                            'walking',
                          ].contains(_sport))
                            _section(
                              '거리 (선택)',
                              _number(
                                _distance,
                                key: const ValueKey('distance'),
                                hint: '0.0',
                                suffix: 'km',
                                optional: true,
                                decimal: true,
                                min: 0.001,
                                max: 1000,
                              ),
                              trailing: distance > 0 && duration > 0
                                  ? Text(
                                      _sport == 'cycling'
                                          ? '평균 ${(distance / duration * 3600).toStringAsFixed(1)} km/h'
                                          : '평균 페이스 ${pace ~/ 60}\'${(pace % 60).toString().padLeft(2, '0')}" /km',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: OunColors.tabAccent,
                                      ),
                                    )
                                  : null,
                            ),
                          if (_sport == 'walking')
                            _section(
                              '걸음 수 (선택)',
                              _number(
                                _steps,
                                hint: '0',
                                suffix: '보',
                                optional: true,
                                max: 60000,
                              ),
                            ),
                          if (_sport == 'weight') ...[
                            _section(
                              '부위',
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final e in bodyPartLabels.entries)
                                    _TypeChip(
                                      label: e.value,
                                      selected: _body == e.key,
                                      onTap: () =>
                                          setState(() => _body = e.key),
                                    ),
                                ],
                              ),
                            ),
                            if (_exercises.isEmpty)
                              _section(
                                !_healthDefaults ? '총 세트 수' : '총 세트 수 (선택)',
                                _number(
                                  _sets,
                                  suffix: '세트',
                                  min: 1,
                                  max: 50,
                                  optional: _healthDefaults,
                                ),
                              )
                            else
                              _section(
                                '운동 · 세트',
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final e in _exercises)
                                      _exerciseCard(e),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            _SoftButton(
                              onTap: _exercises.length >= 30
                                  ? null
                                  : () => setState(
                                      () => _exercises.add(_ExerciseDraft()),
                                    ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 19,
                                    color: OunColors.tabAccent,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '운동 추가 · 중량과 횟수 기록',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: OunColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _detailsCard(),
                          _section('운동 사진 (선택)', _photoSection()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) _errorBanner(_error!),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OunColors.tabAccent,
                  foregroundColor: OunColors.onTabAccent,
                  disabledBackgroundColor: OunColors.tabAccent.withValues(
                    alpha: .7,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: OunColors.onTabAccent,
                        ),
                      )
                    : const Text(
                        '저장하기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
    decoration: BoxDecoration(
      color: const Color(0xFFFBE9E4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: _errorColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _errorColor,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _error = null),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 16, color: _errorColor),
          ),
        ),
      ],
    ),
  );

  /// 라벨(+ 오른쪽 보조 문구) 아래에 입력 위젯을 둔 한 묶음.
  Widget _section(String label, Widget child, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _FieldLabel(label)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  /// 운동 강도 · 칼로리 · 메모를 접었다 펴는 소프트 카드.
  Widget _detailsCard() => Container(
    decoration: BoxDecoration(
      color: OunColors.card,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _showDetails = !_showDetails),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '상세 기록 추가',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: OunColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '운동 강도 · 칼로리 · 메모',
                        style: TextStyle(
                          fontSize: 12,
                          color: OunColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showDetails ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: OunColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_showDetails
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('오늘 얼마나 힘들었나요?'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 1; i <= 10; i++) ...[
                            if (i > 1) const SizedBox(width: 4),
                            Expanded(child: _effortDot(i)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Hint('아주 가벼움'),
                          _Hint('보통'),
                          _Hint('최대 노력'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('칼로리 (선택)'),
                      const SizedBox(height: 8),
                      _number(
                        _calories,
                        hint: '0',
                        suffix: 'kcal',
                        optional: true,
                        max: 100000,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('운동 메모'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _note,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 2000,
                        cursorColor: OunColors.tabAccent,
                        style: _inputStyle.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        decoration: _ounInput(
                          hint: '오늘의 컨디션이나 다음에 기억할 내용을 적어 주세요',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _effortDot(int i) {
    final selected = _effort == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _effort = selected ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OunColors.tabAccent : OunColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OunColors.tabAccent : OunColors.cardBorder,
          ),
        ),
        child: Text(
          '$i',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? OunColors.onTabAccent : OunColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// 운동 인증 사진 영역. 첨부 전/후 상태가 다르다.
  Widget _photoSection() {
    final photo = _photo;
    final existing = _editing ? widget.editing!.photoUrl : null;
    final buttons = Row(
      children: [
        Expanded(
          child: _PhotoOption(
            icon: Icons.photo_camera_outlined,
            label: '촬영',
            onTap: () => _pickPhoto(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _PhotoOption(
            icon: Icons.photo_library_outlined,
            label: existing == null ? '앨범' : '교체',
            onTap: () => _pickPhoto(ImageSource.gallery),
          ),
        ),
      ],
    );
    if (photo != null) {
      return Row(
        children: [
          _thumb(Image.file(File(photo.path), fit: BoxFit.cover)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '사진이 첨부되었어요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OunColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _photo = null),
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: OunColors.textMuted,
            ),
            tooltip: '새 사진 취소',
          ),
        ],
      );
    }
    // 수정 모드: 기존 사진 미리보기(그대로 두면 유지, 새로 골라 교체 가능).
    if (existing != null) {
      return Row(
        children: [
          _thumb(
            Image.network(
              existing,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: OunColors.card,
                child: Icon(Icons.image_outlined, color: OunColors.textFaint),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: buttons),
        ],
      );
    }
    return buttons;
  }

  Widget _thumb(Widget image) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(width: 64, height: 64, child: image),
  );

  Widget _exerciseCard(_ExerciseDraft e) => Container(
    key: ObjectKey(e),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 12, 4, 6),
    decoration: BoxDecoration(
      color: OunColors.card,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: e.name,
                maxLength: 80,
                cursorColor: OunColors.tabAccent,
                style: _inputStyle,
                decoration: _ounInput(hint: '운동 이름 (예: 벤치프레스)'),
                validator: (s) =>
                    s == null || s.trim().isEmpty ? '운동 이름을 입력해 주세요' : null,
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _exercises.remove(e);
                e.dispose();
              }),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: OunColors.textMuted,
              ),
              tooltip: '운동 제거',
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < e.sets.length; i++)
          Padding(
            key: ObjectKey(e.sets[i]),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(top: 11, right: 8),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OunColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OunColors.tabAccent,
                    ),
                  ),
                ),
                Expanded(
                  child: _number(
                    e.sets[i].weight,
                    suffix: 'kg',
                    decimal: true,
                    max: 1000,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _number(
                    e.sets[i].reps,
                    suffix: '회',
                    min: 1,
                    max: 1000,
                  ),
                ),
                IconButton(
                  onPressed: e.sets.length == 1
                      ? null
                      : () => setState(() {
                          e.sets.removeAt(i).dispose();
                        }),
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 20,
                  ),
                  color: OunColors.textMuted,
                  disabledColor: OunColors.cardBorder,
                  tooltip: '세트 제거',
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: e.sets.length >= 50
                ? null
                : () => setState(
                    () => e.sets.add(
                      _SetDraft(
                        weight: e.sets.last.weight.text,
                        count: e.sets.last.reps.text,
                      ),
                    ),
                  ),
            style: TextButton.styleFrom(foregroundColor: OunColors.tabAccent),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              '세트 추가',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

// 삭제 확인 등에서 쓰는 오운 경고색.
const _errorColor = Color(0xFFCC4B37);

const _inputStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: OunColors.textPrimary,
);

/// 오운 입력칸 장식: 밝은 카드 배경 + 웜톤 테두리, 포커스 시 테라코타.
InputDecoration _ounInput({String? hint, String? suffix}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    suffixText: suffix,
    isDense: true,
    filled: true,
    fillColor: OunColors.surface,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    hintStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: OunColors.textFaint,
    ),
    suffixStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: OunColors.textMuted,
    ),
    errorStyle: const TextStyle(fontSize: 11.5),
    errorMaxLines: 2,
    border: border(OunColors.cardBorder),
    enabledBorder: border(OunColors.cardBorder),
    focusedBorder: border(OunColors.tabAccent, 1.4),
  );
}

String _trim(double n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();

/// '10월 6일 (화) · 오후 3:20'
String _dateLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final date = diff == 0
      ? '오늘'
      : diff == 1
      ? '어제'
      : '${d.year == now.year ? '' : '${d.year}년 '}${d.month}월 ${d.day}일 (${'월화수목금토일'[d.weekday - 1]})';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$date · ${d.hour < 12 ? '오전' : '오후'} $h:${d.minute.toString().padLeft(2, '0')}';
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 16),
      decoration: BoxDecoration(
        color: OunColors.cardBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// 시트 안 작은 섹션 라벨.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: OunColors.textMuted),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, color: OunColors.textFaint),
  );
}

/// 밝은 카드 + 웜톤 테두리의 탭 영역(날짜 선택 · 운동 추가 등).
class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .5 : 1,
    child: Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  );
}

/// 사진 소스(촬영/앨범) 선택 버튼.
class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _SoftButton(
    onTap: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: OunColors.tabAccent),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: OunColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// 종목/부위 선택 칩. 선택 시 테라코타로 채워진다.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? OunColors.tabAccent : OunColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected ? OunColors.tabAccent : OunColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: selected ? OunColors.onTabAccent : OunColors.tabAccent,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? OunColors.onTabAccent : OunColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ExerciseDraft {
  _ExerciseDraft() : name = TextEditingController(), sets = [_SetDraft()];
  _ExerciseDraft.fromWorkout(WorkoutExercise e)
    : name = TextEditingController(text: e.name),
      sets = e.sets
          .map((s) => _SetDraft(weight: '${s.weightKg}', count: '${s.reps}'))
          .toList();
  final TextEditingController name;
  final List<_SetDraft> sets;
  WorkoutExercise toWorkout() => WorkoutExercise(
    name: name.text.trim(),
    sets: sets
        .map(
          (s) => WorkoutSet(
            weightKg: double.parse(s.weight.text),
            reps: int.parse(s.reps.text),
          ),
        )
        .toList(),
  );
  void dispose() {
    name.dispose();
    for (final s in sets) {
      s.dispose();
    }
  }
}

class _SetDraft {
  _SetDraft({String weight = '0', String count = '10'})
    : weight = TextEditingController(text: weight),
      reps = TextEditingController(text: count);
  final TextEditingController weight;
  final TextEditingController reps;
  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}
