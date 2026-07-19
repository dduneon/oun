import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

enum CrewQuestState { inProgress, claimable, claimed }

/// 크루 퀘스트: 순위 경쟁 없이 다 같이 채우는 협동 목표.
/// 달성 시 크루원 전원에게 같은 보상 — 오운의 '랭킹 없음' 원칙 유지.
class CrewQuest {
  CrewQuest({
    required this.icon,
    required this.title,
    required this.sub,
    required this.progress,
    required this.goal,
    required this.reward,
    this.state = CrewQuestState.inProgress,
  });

  final IconData icon;
  final String title;
  final String sub;
  final int progress;
  final int goal;
  final int reward; // 1인당 코인
  CrewQuestState state;
}

List<CrewQuest> demoCrewQuests() => [
      CrewQuest(
        icon: Icons.groups_outlined,
        title: '다 같이 20회 운동',
        sub: '이번 주 크루 합산 운동 횟수',
        progress: 14,
        goal: 20,
        reward: 100,
      ),
      CrewQuest(
        icon: Icons.diversity_3_outlined,
        title: '전원 3회 이상',
        sub: '한 명도 빠짐없이 주 3회',
        progress: 2,
        goal: 4,
        reward: 150,
      ),
      CrewQuest(
        icon: Icons.route_outlined,
        title: '누적 30km 달리기',
        sub: '크루 러닝·걷기 거리 합산',
        progress: 30,
        goal: 30,
        reward: 120,
        state: CrewQuestState.claimable,
      ),
    ];

/// 크루 퀘스트 탭: 진행 중 목표 + (방장) 새 퀘스트 만들기.
class CrewQuestsTab extends StatefulWidget {
  const CrewQuestsTab(
      {super.key, required this.quests, required this.isLeader});
  final List<CrewQuest> quests;
  final bool isLeader;

  @override
  State<CrewQuestsTab> createState() => _CrewQuestsTabState();
}

class _CrewQuestsTabState extends State<CrewQuestsTab> {
  void _claim(CrewQuest q) {
    setState(() => q.state = CrewQuestState.claimed);
    OunToast.show(context, '크루 전원에게 +${q.reward} 코인!',
        kind: OunToastKind.success, icon: Icons.paid_rounded);
  }

  Future<void> _create() async {
    final q = await showCrewQuestCreateSheet(context);
    if (q == null) return;
    setState(() => widget.quests.add(q));
    if (mounted) {
      OunToast.show(context, '새 크루 퀘스트를 만들었어요',
          kind: OunToastKind.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        for (final q in widget.quests)
          _CrewQuestCard(quest: q, onClaim: () => _claim(q)),
        if (widget.isLeader) ...[
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: OunColors.cardBorder),
            ),
            child: InkWell(
              onTap: _create,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 19, color: OunColors.tabAccent),
                    SizedBox(width: 7),
                    Text('퀘스트 만들기',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: OunColors.tabAccent)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('달성하면 크루원 모두가 보상을 받아요',
                style: TextStyle(fontSize: 11, color: OunColors.textFaint)),
          ),
        ],
      ],
    );
  }
}

class _CrewQuestCard extends StatelessWidget {
  const _CrewQuestCard({required this.quest, required this.onClaim});
  final CrewQuest quest;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final ratio = (q.progress / q.goal).clamp(0.0, 1.0);
    final claimable = q.state == CrewQuestState.claimable;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: claimable ? OunColors.tabAccent : OunColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: OunColors.card,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(q.icon, size: 19, color: OunColors.tabAccent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.title,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(q.sub,
                        style: const TextStyle(
                            fontSize: 10.5, color: OunColors.textMuted)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.paid_rounded,
                      size: 14, color: OunColors.coin),
                  const SizedBox(width: 3),
                  Text('${q.reward}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: OunColors.textPrimary)),
                  const Text('/인',
                      style: TextStyle(
                          fontSize: 10, color: OunColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: OunColors.card,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        OunColors.tabAccent),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text('${q.progress}/${q.goal}',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: OunColors.textMuted)),
            ],
          ),
          if (q.state != CrewQuestState.inProgress) ...[
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              child: q.state == CrewQuestState.claimable
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: OunColors.tabAccent,
                        foregroundColor: OunColors.onTabAccent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onClaim,
                      child: const Text('보상 받기',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('보상 지급 완료 🎉',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: OunColors.textMuted)),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 방장의 크루 퀘스트 만들기 시트: 템플릿 선택 + 목표 수치.
Future<CrewQuest?> showCrewQuestCreateSheet(BuildContext context) {
  return showModalBottomSheet<CrewQuest>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuestCreateSheet(),
  );
}

class _QuestCreateSheet extends StatefulWidget {
  const _QuestCreateSheet();

  @override
  State<_QuestCreateSheet> createState() => _QuestCreateSheetState();
}

class _QuestCreateSheetState extends State<_QuestCreateSheet> {
  static const _templates = [
    (Icons.groups_outlined, '다 같이 N회 운동', '크루 합산 횟수', 10, 5, 60, '회'),
    (Icons.route_outlined, '누적 N km 이동', '러닝·걷기·자전거 거리 합산', 20, 10, 40, 'km'),
    (Icons.photo_camera_outlined, '인증 사진 N장', '크루 합산 인증 수', 10, 5, 30, '장'),
  ];

  int _template = 0;
  late int _goal = _templates[0].$4;

  @override
  Widget build(BuildContext context) {
    final t = _templates[_template];
    final reward = (_goal ~/ t.$5) * t.$6; // 목표에 비례한 1인당 보상(목업 산식)
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
            const Text('크루 퀘스트 만들기',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
            const SizedBox(height: 16),
            const Text('목표 종류',
                style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
            const SizedBox(height: 8),
            for (var i = 0; i < _templates.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _template = i;
                    _goal = _templates[i].$4;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: OunColors.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: _template == i
                              ? OunColors.tabAccent
                              : OunColors.cardBorder,
                          width: _template == i ? 1.4 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(_templates[i].$1,
                            size: 19,
                            color: _template == i
                                ? OunColors.tabAccent
                                : OunColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_templates[i].$2,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: OunColors.textPrimary)),
                              Text(_templates[i].$3,
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: OunColors.textMuted)),
                            ],
                          ),
                        ),
                        if (_template == i)
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: OunColors.tabAccent),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('목표',
                    style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.paid_rounded,
                        size: 13, color: OunColors.coin),
                    const SizedBox(width: 3),
                    Text('1인당 $reward',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textMuted)),
                  ],
                ),
              ],
            ),
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
                      () => setState(() => _goal = (_goal - t.$5).clamp(t.$5, 999))),
                  Expanded(
                    child: Text('$_goal${t.$7}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textPrimary)),
                  ),
                  _stepBtn(Icons.add_rounded,
                      () => setState(() => _goal = (_goal + t.$5).clamp(t.$5, 999))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OunColors.tabAccent,
                  foregroundColor: OunColors.onTabAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.of(context).pop(CrewQuest(
                  icon: t.$1,
                  title: t.$2.replaceFirst('N', '$_goal'),
                  sub: t.$3,
                  progress: 0,
                  goal: _goal,
                  reward: reward,
                )),
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
