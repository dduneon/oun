import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 소셜 탭: 상단 세그먼트로 친구 / 크루를 통합.
class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  int _segment = 0; // 0: 친구, 1: 크루

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              '소셜',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('친구'), icon: Icon(Icons.people_alt_outlined)),
                ButtonSegment(value: 1, label: Text('크루'), icon: Icon(Icons.groups_outlined)),
              ],
              selected: {_segment},
              onSelectionChanged: (s) => setState(() => _segment = s.first),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _segment == 0 ? Icons.people_alt_outlined : Icons.groups_outlined,
                    size: 48,
                    color: OunColors.textFaint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _segment == 0
                        ? '@닉네임으로 친구를 추가하고 서로 응원해요'
                        : '크루를 만들어 함께 목표를 세워요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: OunColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  const Text('(구현 예정)',
                      style: TextStyle(fontSize: 12, color: OunColors.textFaint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
