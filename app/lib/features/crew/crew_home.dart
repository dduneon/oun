import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../../unity/unity_stage.dart';
import 'crew_feed.dart';
import 'crew_quests.dart';
import 'friend_home_screen.dart';

/// 크루원 한 명(목데이터).
class CrewMember {
  const CrewMember(this.initial, this.color, this.name, this.weekCount,
      {this.leader = false, this.isFemale = true});
  final String initial;
  final Color color;
  final String name;
  final int weekCount; // 이번 주 운동 횟수
  final bool leader;
  final bool isFemale; // 이 크루원이 고른 캐릭터 종류

  /// Unity 크루 씬에 넘길 토큰('f'/'m').
  String get charToken => isFemale ? 'f' : 'm';
}

/// 가입한 크루 하나. 여러 크루에 속할 수 있어 목록으로 관리한다.
class Crew {
  Crew({required this.name, required this.goal, required this.members})
      : posts = demoCrewPosts(),
        quests = demoCrewQuests();
  final String name;
  final int goal; // 1인당 주간 목표
  final List<CrewMember> members;
  final List<CrewPost> posts;
  final List<CrewQuest> quests;

  /// 내가 방장인지(목업: '나'가 leader).
  bool get isLeader => members.any((m) => m.name == '나' && m.leader);

  int get weekDone => members.fold(0, (s, m) => s + m.weekCount);
  int get target => goal * members.length;
}

/// 새 크루의 기본 멤버(목데이터). 실제로는 생성자 본인만 있고 초대로 늘어난다.
List<CrewMember> defaultCrewMembers() => const [
      CrewMember('나', Color(0xFFC47A45), '나', 4, leader: true),
      CrewMember('지', Color(0xFFC9865B), '지민', 5),
      CrewMember('현', Color(0xFF7FA98C), '현우', 3, isFemale: false),
      CrewMember('서', Color(0xFFB58BB0), '서연', 2),
    ];

/// 크루 목록의 카드 한 장(소셜 탭 크루 세그먼트에 표시).
class CrewCard extends StatelessWidget {
  const CrewCard({super.key, required this.crew, required this.onTap});
  final Crew crew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio =
        crew.target == 0 ? 0.0 : (crew.weekDone / crew.target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: OunColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: OunColors.cardBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: OunColors.card,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.groups,
                          size: 24, color: OunColors.tabAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(crew.name,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: OunColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('멤버 ${crew.members.length}명',
                              style: const TextStyle(
                                  fontSize: 11.5, color: OunColors.textMuted)),
                        ],
                      ),
                    ),
                    Text('이번 주 ${crew.weekDone}/${crew.target}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: OunColors.tabAccent)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        size: 18, color: OunColors.textFaint),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: OunColors.card,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        OunColors.tabAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 크루 홈: 상단 라이브 3D 무대(크루원 캐릭터) + 피드/크루원/현황 탭.
///
/// 진입 즉시 전역 Unity 뷰를 크루 씬으로 전환해 무대 영역(투명)으로
/// 캐릭터들이 비쳐 보인다. 무대는 고정 헤더, 아래 탭 콘텐츠만 스크롤.
class CrewHomeScreen extends ConsumerStatefulWidget {
  const CrewHomeScreen({super.key, required this.crew, required this.onLeave});
  final Crew crew;
  final VoidCallback onLeave;

  @override
  ConsumerState<CrewHomeScreen> createState() => _CrewHomeScreenState();
}

class _CrewHomeScreenState extends ConsumerState<CrewHomeScreen> {
  int _tab = 0; // 0: 피드, 1: 퀘스트, 2: 크루원, 3: 현황

  static const _stageHeight = 210.0;
  final _stageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 진입 시 Unity를 크루 씬으로 전환 (복구는 호출측 push-await에서).
    // 각 크루원이 고른 캐릭터 종류를 토큰으로 전달 → 인원수만큼 해당 캐릭터 스폰.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tokens = widget.crew.members.map((m) => m.charToken).join(',');
      ref.read(unitySceneProvider.notifier).showCrew(tokens);
      _syncStageViewport();
    });
  }

  /// 무대 박스의 화면상 위치를 재서 Unity 뷰를 그 영역에만 렌더하게 한다.
  /// 아래 시트의 둥근 모서리 뒤가 검게 비지 않도록, 뷰포트를 시트 안쪽으로
  /// 조금 더(코너 반경만큼) 확장해 그 밑도 Unity가 채우게 한다.
  void _syncStageViewport() {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final size = Size(box.size.width, box.size.height + 28);
    ref.read(unityViewportProvider.notifier).setRect(origin & size);
  }

  @override
  Widget build(BuildContext context) {
    final crew = widget.crew;
    // 배경 투명: 상단 무대 영역으로 전역 Unity(크루 씬)가 비친다.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 상단 바 영역은 배경색으로 채운다(무대 박스만 투명 → Unity가 비침).
          ColoredBox(
            color: OunColors.background,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: OunColors.textPrimary),
                  ),
                Expanded(
                  child: Text(crew.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: OunColors.textPrimary)),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: OunColors.card.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: OunColors.cardBorder),
                  ),
                  child: Text('이번 주 ${crew.weekDone}/${crew.target}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OunColors.tabAccent)),
                ),
                ],
              ),
            ),
          ),
          // 라이브 3D 무대(투명 창): Unity 뷰를 이 박스 크기에 맞춰 렌더한다.
          SizedBox(
            key: _stageKey,
            height: _stageHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('크루원 ${crew.members.length}명이 모여 있어요',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: OunColors.textMuted)),
              ),
            ),
          ),
          // 아래 시트: 탭 + 콘텐츠 (불투명 → Unity 가림)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: OunColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: _TabBar(
                      value: _tab,
                      onChanged: (v) => setState(() => _tab = v),
                    ),
                  ),
                  Expanded(child: _content(crew)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(Crew crew) {
    switch (_tab) {
      case 0:
        return _FeedTab(crew: crew);
      case 1:
        return CrewQuestsTab(quests: crew.quests, isLeader: crew.isLeader);
      case 2:
        return _MembersTab(crew: crew);
      default:
        return _StatusTab(
            crew: crew,
            onLeave: () {
              widget.onLeave();
              Navigator.of(context).pop();
              OunToast.show(context, '${crew.name}에서 나왔어요');
            });
    }
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['피드', '퀘스트', '크루원', '현황'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: OunColors.card, borderRadius: BorderRadius.circular(13)),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: value == i ? OunColors.surface : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: value == i
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

/// 피드 탭: SNS처럼 크루원들의 운동 공유 글.
class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.crew});
  final Crew crew;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        for (final p in crew.posts)
          CrewPostCard(
            post: p,
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => CrewPostDetailScreen(post: p),
              ),
            ),
          ),
        const SizedBox(height: 4),
        const Center(
          child: Text('운동을 기록하면 크루에 공유할 수 있어요',
              style: TextStyle(fontSize: 11.5, color: OunColors.textFaint)),
        ),
      ],
    );
  }
}

/// 크루원 탭: 멤버 관리 + 초대.
class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.crew});
  final Crew crew;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        for (final m in crew.members) _MemberRow(m),
        const SizedBox(height: 8),
        _InviteRow(),
      ],
    );
  }
}

/// 현황 탭: 크루 공동 목표 + 관리.
class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.crew, required this.onLeave});
  final Crew crew;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final ratio =
        crew.target == 0 ? 0.0 : (crew.weekDone / crew.target).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OunColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OunColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('이번 주 함께한 운동',
                      style:
                          TextStyle(fontSize: 12, color: OunColors.textMuted)),
                  const Spacer(),
                  Text('${crew.weekDone} / ${crew.target}회',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: OunColors.tabAccent)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 9,
                  backgroundColor: OunColors.card,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(OunColors.tabAccent),
                ),
              ),
              const SizedBox(height: 10),
              Text('멤버 ${crew.members.length}명 · 1인당 주 ${crew.goal}회 목표',
                  style: const TextStyle(
                      fontSize: 11.5, color: OunColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 멤버별 이번 주 참여
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OunColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OunColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('멤버별 이번 주',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OunColors.textMuted)),
              const SizedBox(height: 10),
              for (final m in crew.members) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(m.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: OunColors.textPrimary)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (m.weekCount / crew.goal).clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: OunColors.card,
                            valueColor: AlwaysStoppedAnimation<Color>(m.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${m.weekCount}회',
                          style: const TextStyle(
                              fontSize: 11, color: OunColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: onLeave,
            child: const Text('크루 나가기',
                style: TextStyle(fontSize: 12.5, color: OunColors.textMuted)),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(this.m);
  final CrewMember m;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => FriendHomeScreen(
                name: m.name, initial: m.initial, color: m.color),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: m.color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(m.initial,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Row(
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: OunColors.textPrimary)),
                  if (m.leader) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: OunColors.card,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('방장',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: OunColors.tabAccent)),
                    ),
                  ],
                ],
              ),
            ),
            Text('이번 주 ${m.weekCount}회',
                style: const TextStyle(
                    fontSize: 11.5, color: OunColors.textMuted)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: OunColors.textFaint),
          ],
        ),
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: () => OunToast.show(context, '초대 링크 공유는 곧 열려요'),
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_alt, size: 17, color: OunColors.tabAccent),
              SizedBox(width: 8),
              Text('크루원 초대하기',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OunColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
