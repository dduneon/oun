import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

/// 마이룸·프로필·월말 리포트·설정.
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: '마이',
      icon: Icons.person_outline,
      description: '마이룸·리포트·설정을 관리해요',
    );
  }
}
