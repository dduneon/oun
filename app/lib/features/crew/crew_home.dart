import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../../unity/unity_stage.dart';
import 'crew_stage_screen.dart';
import 'friend_home_screen.dart';

/// 크루원 한 명(목데이터).
class CrewMember {
  const CrewMember(this.initial, this.color, this.name, this.weekCount,
      {this.leader = false});
  final String initial;
  final Color color;
  final String name;
  final int weekCount; // 이번 주 운동 횟수
  final bool leader;
}

/// 가입한 크루 하나. 여러 크루에 속할 수 있어 목록으로 관리한다.
class Crew {
  const Crew({required this.name, required this.goal, required this.members});
  final String name;
  final int goal; // 1인당 주간 목표
  final List<CrewMember> members;

  int get weekDone => members.fold(0, (s, m) => s + m.weekCount);
  int get target => goal * members.length;
}

/// 새 크루의 기본 멤버(목데이터). 실제로는 생성자 본인만 있고 초대로 늘어난다.
List<CrewMember> defaultCrewMembers() => const [
      CrewMember('나', Color(0xFFC47A45), '나', 4, leader: true),
      CrewMember('지', Color(0xFFC9865B), '지민', 5),
      CrewMember('현', Color(0xFF7FA98C), '현우', 3),
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

/// 크루 홈(상세) 전체 화면: 목표 진행 + 크루원 관리 + 활동 피드.
class CrewHomeScreen extends ConsumerWidget {
  const CrewHomeScreen({super.key, required this.crew, required this.onLeave});
  final Crew crew;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: Text(crew.name,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          // 탭하면 라이브 3D 크루 광장으로. 돌아오면 홈 씬으로 확실히 복구.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => CrewStageScreen(crew: crew),
                ),
              );
              ref.read(unitySceneProvider.notifier).showHome();
            },
            child: _CrewGathering(members: crew.members),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('탭하면 크루 광장에서 다 같이 만나요',
                style: TextStyle(fontSize: 11.5, color: OunColors.textMuted)),
          ),
          const SizedBox(height: 14),
          _GoalCard(crew: crew),
          const SizedBox(height: 20),
          const _SectionLabel('크루원'),
          const SizedBox(height: 8),
          for (final m in crew.members) _MemberRow(m),
          const SizedBox(height: 8),
          _InviteRow(),
          const SizedBox(height: 20),
          const _SectionLabel('크루 활동'),
          const SizedBox(height: 8),
          const _FeedRow(
              '지민', Color(0xFFC9865B), Icons.directions_run, '러닝 5.2km', '오늘'),
          const _FeedRow('현우', Color(0xFF7FA98C), Icons.fitness_center,
              '웨이트 · 하체', '오늘'),
          const _FeedRow('서연', Color(0xFFB58BB0), Icons.directions_walk,
              '걷기 8,200보', '어제'),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () {
                onLeave();
                Navigator.of(context).pop();
                OunToast.show(context, '${crew.name}에서 나왔어요');
              },
              child: const Text('크루 나가기',
                  style:
                      TextStyle(fontSize: 12.5, color: OunColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 크루 광장: 크루원 캐릭터들이 한 무대에 모여 있는 장면.
/// 실시간 3D는 홈의 단일 Unity 인스턴스 제약으로 불가 → 캐릭터별 정적
/// 스냅샷을 한 화면에 배치(지금은 자리표시 아바타). 추후 서버 렌더로 교체.
class _CrewGathering extends StatelessWidget {
  const _CrewGathering({required this.members});
  final List<CrewMember> members;

  @override
  Widget build(BuildContext context) {
    const maxShown = 5;
    final shown = members.take(maxShown).toList();
    final extra = members.length - shown.length;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OunColors.cardBorder),
        gradient: const RadialGradient(
          center: Alignment(0, 0.9),
          radius: 1.1,
          colors: [Color(0xFFF6E4D0), OunColors.card],
          stops: [0.0, 0.75],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final n = shown.length;
          final figures = <Widget>[];
          for (var i = 0; i < n; i++) {
            final t = n == 1 ? 0.5 : i / (n - 1);
            // 뒷줄(홀수)은 조금 작고 위로 → 모여 있는 깊이감
            final back = i.isOdd;
            final size = back ? 52.0 : 64.0;
            final cx = w * (0.16 + 0.68 * t);
            final bottom = back ? 58.0 : 40.0;
            figures.add(Positioned(
              left: cx - size / 2,
              bottom: bottom,
              child: _Figure(
                  member: shown[i], size: size, phase: i * 0.19),
            ));
          }
          // 앞줄이 위에 오도록 뒤(작은)부터 그리기
          figures.sort((a, b) {
            final pa = a as Positioned, pb = b as Positioned;
            return (pb.bottom ?? 0).compareTo(pa.bottom ?? 0);
          });
          return Stack(
            children: [
              ...figures,
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Text(
                  extra > 0
                      ? '크루원 ${members.length}명이 모여 있어요 (+$extra)'
                      : '크루원 ${members.length}명이 모여 있어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: OunColors.textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 무대 위 캐릭터 한 명(자리표시 아바타 + 바닥 그림자).
/// 정적 이미지지만 은은한 둥실거림 + 탭하면 통통 튀어 생기를 준다.
class _Figure extends StatefulWidget {
  const _Figure(
      {required this.member, required this.size, required this.phase});
  final CrewMember member;
  final double size;
  final double phase; // 캐릭터마다 위상 차 → 제각각 움직임

  @override
  State<_Figure> createState() => _FigureState();
}

class _FigureState extends State<_Figure> with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _pop;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.16)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 1.16, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 1),
    ]).animate(_pop);
  }

  @override
  void dispose() {
    _bob.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final size = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pop.forward(from: 0),
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _pop]),
        builder: (context, _) {
          final dy = reduce
              ? 0.0
              : math.sin((_bob.value + widget.phase) * 2 * math.pi) * 5;
          final lift = (-dy).clamp(0.0, 5.0) / 5.0; // 위로 뜬 정도 0~1
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: _popScale.value,
                  child: _avatar(size),
                ),
              ),
              const SizedBox(height: 5),
              // 뜰수록 그림자는 작고 옅게
              Transform.scale(
                scale: 1 - lift * 0.2,
                child: Opacity(
                  opacity: 1 - lift * 0.3,
                  child: Container(
                    width: size * 0.6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: OunColors.textPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _avatar(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: widget.member.color,
          shape: BoxShape.circle,
          border: Border.all(color: OunColors.background, width: 2),
          boxShadow: [
            BoxShadow(
              color: OunColors.textPrimary.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(widget.member.initial,
            style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.crew});
  final Crew crew;

  @override
  Widget build(BuildContext context) {
    final ratio =
        crew.target == 0 ? 0.0 : (crew.weekDone / crew.target).clamp(0.0, 1.0);
    return Container(
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
                  style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
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
              style: const TextStyle(fontSize: 11.5, color: OunColors.textMuted)),
        ],
      ),
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

class _FeedRow extends StatelessWidget {
  const _FeedRow(this.name, this.color, this.icon, this.activity, this.when);
  final String name;
  final Color color;
  final IconData icon;
  final String activity;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                    fontSize: 12.5, color: OunColors.textPrimary),
                children: [
                  TextSpan(
                      text: name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: ' · $activity',
                      style: const TextStyle(color: OunColors.textMuted)),
                ],
              ),
            ),
          ),
          Text(when,
              style: const TextStyle(fontSize: 11, color: OunColors.textFaint)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      );
}
