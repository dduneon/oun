import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 오운 토스트 종류. 아이콘/강조색 프리셋.
enum OunToastKind { success, info, cheer }

/// 오운 톤의 플로팅 토스트(스낵바). 앱 전역에서 동일한 모양으로 알림을 띄운다.
///
/// 사용: `OunToast.show(context, '러닝 30분 기록했어요', kind: OunToastKind.success)`
class OunToast {
  const OunToast._();

  static void show(
    BuildContext context,
    String message, {
    OunToastKind kind = OunToastKind.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        padding: EdgeInsets.zero,
        // 기본 스낵바 여백을 없애고 커스텀 카드가 폭을 잡게 한다.
        content: _ToastCard(message: message, kind: kind, icon: icon),
      ),
    );
  }

  /// messenger를 미리 확보해 둔 경우(예: 시트 pop 이후)용 오버로드.
  static void showWith(
    ScaffoldMessengerState messenger,
    String message, {
    OunToastKind kind = OunToastKind.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        padding: EdgeInsets.zero,
        content: _ToastCard(message: message, kind: kind, icon: icon),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message, required this.kind, this.icon});
  final String message;
  final OunToastKind kind;
  final IconData? icon;

  IconData get _icon {
    if (icon != null) return icon!;
    switch (kind) {
      case OunToastKind.success:
        return Icons.check_circle_rounded;
      case OunToastKind.cheer:
        return Icons.favorite_rounded;
      case OunToastKind.info:
        return Icons.info_rounded;
    }
  }

  Color get _accent {
    switch (kind) {
      case OunToastKind.success:
        return OunColors.tabAccent;
      case OunToastKind.cheer:
        return const Color(0xFFD98A88);
      case OunToastKind.info:
        return OunColors.seed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: OunColors.textPrimary.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 18, color: _accent),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: OunColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
