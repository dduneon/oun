import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 액션 시트 항목.
class OunAction {
  const OunAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

/// 앱 톤에 맞춘 하단 액션 시트(둥근 상단 · 핸들바 · 따뜻한 팔레트).
/// ⋮ 메뉴 대신 이걸 써서 수정/삭제 등 항목을 보여준다.
Future<void> showOunActionSheet(
  BuildContext context, {
  required List<OunAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: const BoxDecoration(
          color: OunColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                    color: OunColors.cardBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
              for (final a in actions)
                _ActionRow(
                  action: a,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    a.onSelected();
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onTap});
  final OunAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? const Color(0xFFCC4B37)
        : OunColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        child: Row(
          children: [
            Icon(action.icon, size: 21, color: color),
            const SizedBox(width: 14),
            Text(action.label,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
