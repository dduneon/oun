import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 크루 만들기 바텀시트. 이름 + 주간 목표를 받아 (이름, 목표)로 돌려준다.
Future<(String, int)?> showCrewCreateSheet(BuildContext context) {
  return showModalBottomSheet<(String, int)>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CrewCreateSheet(),
  );
}

class _CrewCreateSheet extends StatefulWidget {
  const _CrewCreateSheet();

  @override
  State<_CrewCreateSheet> createState() => _CrewCreateSheetState();
}

class _CrewCreateSheetState extends State<_CrewCreateSheet> {
  final _name = TextEditingController();
  int _goal = 3;

  @override
  void dispose() {
    _name.dispose();
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
            const Text('크루 만들기',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
            const SizedBox(height: 16),
            const _Label('크루 이름'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              maxLength: 20,
              style: const TextStyle(
                  fontSize: 14, color: OunColors.textPrimary),
              decoration: InputDecoration(
                hintText: '예: 아침 러닝 크루',
                hintStyle: const TextStyle(color: OunColors.textFaint),
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
            ),
            const SizedBox(height: 16),
            const _Label('주간 목표 (1인당)'),
            const SizedBox(height: 8),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: OunColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OunColors.cardBorder),
              ),
              child: Row(
                children: [
                  _stepBtn(Icons.remove_rounded,
                      () => setState(() => _goal = (_goal - 1).clamp(1, 14))),
                  Expanded(
                    child: Text('주 $_goal회',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textPrimary)),
                  ),
                  _stepBtn(Icons.add_rounded,
                      () => setState(() => _goal = (_goal + 1).clamp(1, 14))),
                ],
              ),
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
                    ? () => Navigator.of(context).pop((_name.text.trim(), _goal))
                    : null,
                child: const Text('만들기',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => Material(
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, color: OunColors.textMuted));
}
