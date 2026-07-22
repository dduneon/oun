import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 크루 만들기 결과: 이름 · 소개 · 공개여부.
typedef CrewCreateResult = ({String name, String? description, bool isPublic});

/// 크루 만들기 바텀시트. 이름 + 소개 + 공개여부를 받는다.
Future<CrewCreateResult?> showCrewCreateSheet(BuildContext context) {
  return showModalBottomSheet<CrewCreateResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CrewCreateSheet(),
  );
}

/// 크루 설정 편집 바텀시트(기존 값으로 채워 시작). 만들기 시트와 폼을 공유한다.
Future<CrewCreateResult?> showCrewEditSheet(
  BuildContext context, {
  required String initialName,
  required String initialDescription,
  required bool initialIsPublic,
}) {
  return showModalBottomSheet<CrewCreateResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CrewCreateSheet(
      title: '크루 설정',
      actionLabel: '저장',
      initialName: initialName,
      initialDescription: initialDescription,
      initialIsPublic: initialIsPublic,
    ),
  );
}

class _CrewCreateSheet extends StatefulWidget {
  const _CrewCreateSheet({
    this.title = '크루 만들기',
    this.actionLabel = '만들기',
    this.initialName = '',
    this.initialDescription = '',
    this.initialIsPublic = true,
  });
  final String title;
  final String actionLabel;
  final String initialName;
  final String initialDescription;
  final bool initialIsPublic;

  @override
  State<_CrewCreateSheet> createState() => _CrewCreateSheetState();
}

class _CrewCreateSheetState extends State<_CrewCreateSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _desc = TextEditingController(text: widget.initialDescription);
  late bool _isPublic = widget.initialIsPublic;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canCreate = _name.text.trim().isNotEmpty;
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
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OunColors.textPrimary)),
              const SizedBox(height: 16),
              const _Label('크루 이름'),
              const SizedBox(height: 8),
              _Field(
                controller: _name,
                hint: '예: 아침 러닝 크루',
                maxLength: 20,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              const _Label('크루 소개 (선택)'),
              const SizedBox(height: 8),
              _Field(
                controller: _desc,
                hint: '어떤 크루인지, 어떤 사람과 함께하고 싶은지 적어보세요',
                maxLength: 200,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const _Label('공개 설정'),
              const SizedBox(height: 8),
              _VisibilityToggle(
                isPublic: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OunColors.tabAccent,
                    foregroundColor: OunColors.onTabAccent,
                    disabledBackgroundColor: OunColors.cardBorder,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: canCreate
                      ? () => Navigator.of(context).pop((
                            name: _name.text.trim(),
                            description: _desc.text.trim().isEmpty
                                ? null
                                : _desc.text.trim(),
                            isPublic: _isPublic,
                          ))
                      : null,
                  child: Text(widget.actionLabel,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.isPublic, required this.onChanged});
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _option(
            selected: isPublic,
            icon: Icons.public,
            title: '공개',
            subtitle: '탐방에 노출 · 가입 신청 받기',
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _option(
            selected: !isPublic,
            icon: Icons.lock_outline,
            title: '비공개',
            subtitle: '초대로만 가입',
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }

  Widget _option({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? OunColors.tabAccent : OunColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? OunColors.tabAccent : OunColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? OunColors.onTabAccent : OunColors.tabAccent),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? OunColors.onTabAccent
                        : OunColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: selected
                        ? OunColors.onTabAccent.withValues(alpha: 0.85)
                        : OunColors.textFaint)),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int maxLines;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      textInputAction:
          maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: maxLines,
      style: const TextStyle(fontSize: 14, color: OunColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: OunColors.textFaint, fontSize: 13),
        counterText: '',
        filled: true,
        fillColor: OunColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OunColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OunColors.tabAccent),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, color: OunColors.textMuted));
}
