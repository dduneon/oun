import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../unity/unity_stage.dart';
import 'crew_home.dart';

/// 크루 광장(라이브 3D). 전역 Unity 뷰를 '크루 씬'으로 전환해 크루원들의
/// 캐릭터가 한 무대에 모여 살아 움직인다. 화면은 투명하게 두어 뒤의 Unity가
/// 비치고, 그 위에 이름표·닫기 같은 UI만 얹는다.
///
/// Unity 측 준비 사항(에디터 작업): OunBridge.LoadScene("crew:이름,이름...")를
/// 받아 크루 씬을 로드하고 멤버 캐릭터를 스폰. 준비되면 SendToFlutter로
/// "crew_ready"를 보내면 로딩 오버레이가 사라진다.
class CrewStageScreen extends ConsumerStatefulWidget {
  const CrewStageScreen({super.key, required this.crew});
  final Crew crew;

  @override
  ConsumerState<CrewStageScreen> createState() => _CrewStageScreenState();
}

class _CrewStageScreenState extends ConsumerState<CrewStageScreen> {
  @override
  void initState() {
    super.initState();
    // 진입 시 Unity를 크루 씬으로 전환.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final names = widget.crew.members.map((m) => m.name).join(',');
      ref.read(unitySceneProvider.notifier).showCrew(names);
    });
  }

  // 홈 씬 복구는 호출측(크루 홈)에서 push await 후 확실히 수행한다.
  // (dispose 시점의 Riverpod 상태 변경은 무시될 수 있어 신뢰하지 않는다.)

  @override
  Widget build(BuildContext context) {
    // 투명 배경: 뒤의 전역 Unity(크루 씬)가 비쳐 보인다.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 하단 이름표가 잘 보이도록 옅은 그라데이션
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      OunColors.background.withValues(alpha: 0.85),
                      OunColors.background.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: OunColors.textPrimary),
                    ),
                    Expanded(
                      child: Text('${widget.crew.name} 광장',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OunColors.textPrimary)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const Spacer(),
                // 크루원 이름표
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in widget.crew.members)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: OunColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: OunColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                    color: m.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(m.name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: OunColors.textPrimary)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
