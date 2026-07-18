import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';
import 'friend_home_screen.dart';

/// 소셜 탭: 상단 세그먼트로 친구 / 크루 통합. 랭킹 없이 응원 중심 피드.
class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  int _segment = 0; // 0: 친구, 1: 크루

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '소셜',
      children: [
        _Segment(
          value: _segment,
          onChanged: (v) => setState(() => _segment = v),
        ),
        const SizedBox(height: 14),
        if (_segment == 0) ..._friends else _crewEmpty,
      ],
    );
  }

  List<Widget> get _friends => [
        // 친구 추가 진입점(검색 필드 모양, 탭하면 추가 플로우 예정)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: OunColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: OunColors.cardBorder),
            ),
            child: Builder(
              builder: (context) => InkWell(
                onTap: () => OunToast.show(context, '친구 추가는 곧 열려요'),
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt,
                          size: 17, color: OunColors.textMuted),
                      SizedBox(width: 8),
                      Text('@닉네임으로 친구 추가',
                          style: TextStyle(
                              fontSize: 13, color: OunColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const _FriendRow(
            '지', Color(0xFFC9865B), '지민', '러닝 5.2km · 오늘 완료', ['👏', '❤️']),
        const _FriendRow('현', Color(0xFF7FA98C), '현우', '웨이트 · 3일 연속', ['🔥']),
        const _FriendRow('서', Color(0xFFB58BB0), '서연', '걷기 1만보 달성', ['👏', '🎉']),
        const _FriendRow('민', Color(0xFFC99F5B), '민준', '오늘 휴식일 🌙', ['💛']),
      ];

  Widget get _crewEmpty => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Icon(Icons.groups_outlined,
                size: 48, color: OunColors.textFaint),
            const SizedBox(height: 12),
            const Text('아직 소속된 크루가 없어요',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: OunColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('크루를 만들어 함께 목표를 세워요',
                style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OunColors.tabAccent,
                foregroundColor: OunColors.onTabAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => OunToast.show(context, '크루 만들기는 곧 열려요'),
              child: const Text('크루 만들기',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: OunColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final e in const [(0, '친구'), (1, '크루')])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(e.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: value == e.$1 ? OunColors.surface : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(e.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: value == e.$1
                              ? OunColors.textPrimary
                              : OunColors.textMuted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow(
      this.initial, this.color, this.name, this.activity, this.reactions);
  final String initial;
  final Color color;
  final String name;
  final String activity;
  final List<String> reactions;

  void _openFriendHome(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FriendHomeScreen(name: name, initial: initial, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          // 아바타 + 이름 영역: 탭하면 친구 홈으로 이동
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openFriendHome(context),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initial,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: OunColors.textPrimary)),
                        Text(activity,
                            style: const TextStyle(
                                fontSize: 11, color: OunColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              for (final r in reactions)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: OunColors.card, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(r, style: const TextStyle(fontSize: 13)),
                ),
              // 응원 보내기 버튼
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(
                      side: BorderSide(color: OunColors.cardBorder)),
                  child: InkWell(
                    onTap: () => OunToast.show(
                      context,
                      '$name님에게 응원을 보냈어요',
                      kind: OunToastKind.cheer,
                    ),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.add_rounded,
                          size: 16, color: OunColors.textMuted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
