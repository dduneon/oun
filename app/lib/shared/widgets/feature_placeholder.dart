import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 아직 구현 전인 탭 화면용 공통 플레이스홀더.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: OunColors.textFaint),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: OunColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '(구현 예정)',
                    style: TextStyle(fontSize: 12, color: OunColors.textFaint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
