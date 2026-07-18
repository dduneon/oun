import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

/// 운동 기록·입력 (웨이트/러닝 등). 헬스 데이터 검증 연동 예정.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: '기록',
      icon: Icons.fitness_center_outlined,
      description: '운동을 기록하고 종목별 스탯을 쌓아요',
    );
  }
}
