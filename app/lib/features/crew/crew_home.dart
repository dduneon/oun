import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import 'crew_feed.dart';
import 'friend_home_screen.dart';
import 'crew_level.dart';

/// 크루 목록의 카드 한 장(소셜 탭 크루 세그먼트에 표시). (서버 CrewCardData)
class CrewCard extends StatelessWidget {
  const CrewCard({super.key, required this.crew, required this.onTap});
  final CrewCardData crew;
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
                          Text('멤버 ${crew.memberCount}명 · Lv.${crew.level.level}',
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

/// 크루 홈: 상단 크루원 무대 + 피드/크루원/현황/정보 탭. (서버 상세)
///
/// 무대는 크루원 아바타가 모여 있는 Flutter 표현. (3D 크루 씬은 Unity 크루
/// 씬 export가 준비되면 이 무대만 교체하면 된다.)
class CrewHomeScreen extends ConsumerStatefulWidget {
  const CrewHomeScreen({super.key, required this.crewId, required this.name});
  final String crewId;
  final String name; // 로딩 중 표시용 초기 이름

  @override
  ConsumerState<CrewHomeScreen> createState() => _CrewHomeScreenState();
}

class _CrewHomeScreenState extends ConsumerState<CrewHomeScreen> {
  int _tab = 0; // 0: 피드, 1: 크루원, 2: 현황, 3: 크루 정보

  static const _stageHeight = 210.0;

  Future<void> _leave(CrewDetail crew) async {
    try {
      await ref.read(apiClientProvider).leaveCrew(crew.id);
      ref.invalidate(crewsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        OunToast.show(context, '${crew.name}에서 나왔어요');
      }
    } catch (_) {
      if (mounted) OunToast.show(context, '크루 나가기에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(crewDetailProvider(widget.crewId));
    final crew = async.value;

    return Scaffold(
      backgroundColor: OunColors.background,
      body: Column(
        children: [
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(crew?.name ?? widget.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: OunColors.textPrimary)),
                        ),
                        const SizedBox(width: 7),
                        if (crew != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: OunColors.tabAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Lv.${crew.level.level}',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: OunColors.onTabAccent)),
                          ),
                      ],
                    ),
                  ),
                  if (crew != null)
                    Container(
                      margin: const EdgeInsets.only(right: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
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
          // 크루원 무대: 아바타들이 모여 있는 표현.
          SizedBox(
            height: _stageHeight,
            child: _CrewStage(members: crew?.members),
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
                  Expanded(
                    child: crew == null
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: OunColors.tabAccent))
                        : _content(crew),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(CrewDetail crew) {
    switch (_tab) {
      case 0:
        return _FeedTab(crewId: crew.id);
      case 1:
        return _MembersTab(crew: crew);
      case 2:
        return _StatusTab(crew: crew);
      default:
        return _CrewInfoTab(crew: crew, onLeave: () => _leave(crew));
    }
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['피드', '크루원', '현황', '크루 정보'];

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

/// 크루원 무대: 아바타들이 바닥에 모여 있는 따뜻한 표현.
/// (3D 크루 씬 Unity export가 준비되면 이 위젯만 교체)
class _CrewStage extends StatelessWidget {
  const _CrewStage({required this.members});
  final List<CrewMemberData>? members;

  @override
  Widget build(BuildContext context) {
    final list = members ?? const <CrewMemberData>[];
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [OunColors.background, OunColors.card],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (members == null)
            const CircularProgressIndicator(color: OunColors.tabAccent)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: [
                  for (final m in list.take(6)) _StageAvatar(m),
                ],
              ),
            ),
          Positioned(
            bottom: 8,
            child: Text(
                members == null
                    ? '크루원을 불러오는 중…'
                    : '크루원 ${list.length}명이 모여 있어요',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: OunColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _StageAvatar extends StatelessWidget {
  const _StageAvatar(this.m);
  final CrewMemberData m;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: avatarColor(m.nickname),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: OunColors.textPrimary.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(initialOf(m.displayName),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        const SizedBox(height: 5),
        Text(m.isMe ? '나' : m.displayName,
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: OunColors.textPrimary)),
      ],
    );
  }
}

/// 피드 탭: SNS처럼 크루원들의 운동 공유 글. (서버 피드)
class _FeedTab extends ConsumerWidget {
  const _FeedTab({required this.crewId});
  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crewFeedProvider(crewId));
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: OunColors.tabAccent)),
      error: (_, _) => const Center(
        child: Text('피드를 불러오지 못했어요',
            style: TextStyle(fontSize: 12, color: OunColors.textFaint)),
      ),
      data: (posts) => RefreshIndicator(
        color: OunColors.tabAccent,
        onRefresh: () async => ref.invalidate(crewFeedProvider(crewId)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            _ComposeBar(crewId: crewId),
            const SizedBox(height: 12),
            for (final p in posts)
              CrewPostCard(
                post: p,
                onTap: () async {
                  await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CrewPostDetailScreen(post: p),
                    ),
                  );
                  ref.invalidate(crewFeedProvider(crewId));
                },
              ),
            if (posts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(
                  child: Text('아직 글이 없어요 · 운동 기록을 태그해 첫 글을 올려보세요',
                      style: TextStyle(
                          fontSize: 11.5, color: OunColors.textFaint)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 피드 상단 글쓰기 진입 바.
class _ComposeBar extends ConsumerWidget {
  const _ComposeBar({required this.crewId});
  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: () => showCrewPostComposer(context, crewId),
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 17, color: OunColors.tabAccent),
              SizedBox(width: 9),
              Text('오늘 운동을 공유해 보세요',
                  style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
              Spacer(),
              Icon(Icons.add_rounded, size: 18, color: OunColors.tabAccent),
            ],
          ),
        ),
      ),
    );
  }
}

/// 크루원 탭: 멤버 관리 + 초대.
class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.crew});
  final CrewDetail crew;

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final nickname = await showNicknameInputSheet(
      context,
      title: '크루원 초대하기',
      hint: '@닉네임 입력',
      action: '초대',
    );
    if (nickname == null || nickname.isEmpty) return;
    try {
      final name =
          await ref.read(apiClientProvider).inviteToCrew(crew.id, nickname);
      ref.invalidate(crewDetailProvider(crew.id));
      ref.invalidate(crewsProvider);
      if (context.mounted) {
        OunToast.show(context, '$name님을 초대했어요', kind: OunToastKind.success);
      }
    } catch (_) {
      if (context.mounted) {
        OunToast.show(context, '초대에 실패했어요. 닉네임을 확인해 주세요');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        for (final m in crew.members) _MemberRow(m),
        const SizedBox(height: 8),
        Material(
          color: OunColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: OunColors.cardBorder),
          ),
          child: InkWell(
            onTap: () => _invite(context, ref),
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_alt,
                      size: 17, color: OunColors.tabAccent),
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
        ),
      ],
    );
  }
}

/// 현황 탭: 크루 공동 목표 + 크루원들이 이번 주 얼마나 운동했는지.
class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.crew});
  final CrewDetail crew;

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
              Text('멤버 ${crew.members.length}명 · 1인당 주 ${crew.weeklyGoal}회 목표',
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
                        width: 52,
                        child: Text(m.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: OunColors.textPrimary)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: crew.weeklyGoal == 0
                                ? 0
                                : (m.weekCount / crew.weeklyGoal)
                                    .clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: OunColors.card,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                avatarColor(m.nickname)),
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
      ],
    );
  }
}

/// 크루 정보 탭: 크루 레벨 + 레벨 보상 + 크루 나가기. (서버 보상 수령)
class _CrewInfoTab extends ConsumerWidget {
  const _CrewInfoTab({required this.crew, required this.onLeave});
  final CrewDetail crew;
  final VoidCallback onLeave;

  Future<void> _claim(
      BuildContext context, WidgetRef ref, int level) async {
    try {
      final (coins, _) =
          await ref.read(apiClientProvider).claimCrewReward(crew.id, level);
      ref.invalidate(crewRewardsProvider(crew.id));
      ref.invalidate(walletProvider);
      if (context.mounted) {
        OunToast.show(
          context,
          coins > 0 ? '+$coins 코인!' : '보상 획득!',
          kind: OunToastKind.success,
          icon: coins > 0 ? Icons.paid_rounded : Icons.emoji_events,
        );
      }
    } catch (_) {
      if (context.mounted) OunToast.show(context, '보상 수령에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(crewRewardsProvider(crew.id)).value ?? [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        CrewLevelCard(info: crew.level),
        const SizedBox(height: 12),
        CrewLevelRewardList(
          rewards: rewards,
          onClaim: (r) => _claim(context, ref, r.level),
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
  final CrewMemberData m;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => FriendHomeScreen(
                nickname: m.nickname, displayName: m.displayName),
          ),
        ),
        child: Row(
          children: [
            PostAvatar(name: m.displayName, nickname: m.nickname, size: 38),
            const SizedBox(width: 11),
            Expanded(
              child: Row(
                children: [
                  Text(m.isMe ? '나' : m.displayName,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: OunColors.textPrimary)),
                  if (m.role == 'leader') ...[
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

/// 닉네임 입력 바텀시트(친구 추가/크루 초대 공용).
Future<String?> showNicknameInputSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NicknameSheet(title: title, hint: hint, action: action),
  );
}

class _NicknameSheet extends StatefulWidget {
  const _NicknameSheet(
      {required this.title, required this.hint, required this.action});
  final String title;
  final String hint;
  final String action;

  @override
  State<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends State<_NicknameSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;
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
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => canSubmit
                  ? Navigator.of(context).pop(_controller.text.trim())
                  : null,
              maxLength: 20,
              style:
                  const TextStyle(fontSize: 14, color: OunColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(color: OunColors.textFaint),
                counterText: '',
                prefixText: '@ ',
                prefixStyle:
                    const TextStyle(color: OunColors.tabAccent, fontSize: 14),
                filled: true,
                fillColor: OunColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: OunColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: OunColors.tabAccent),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OunColors.tabAccent,
                  foregroundColor: OunColors.onTabAccent,
                  disabledBackgroundColor: OunColors.cardBorder,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: canSubmit
                    ? () => Navigator.of(context).pop(_controller.text.trim())
                    : null,
                child: Text(widget.action,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
