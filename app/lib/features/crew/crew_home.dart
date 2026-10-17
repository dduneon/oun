import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../character/character_avatar.dart';
import 'crew_create_sheet.dart';
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
    final hasDesc = crew.description != null && crew.description!.isNotEmpty;
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(crew.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: OunColors.textPrimary)),
                          ),
                          const SizedBox(width: 6),
                          Icon(crew.isPublic ? Icons.public : Icons.lock_outline,
                              size: 13, color: OunColors.textFaint),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('멤버 ${crew.memberCount}명 · Lv.${crew.level.level}',
                          style: const TextStyle(
                              fontSize: 11.5, color: OunColors.textMuted)),
                      if (hasDesc) ...[
                        const SizedBox(height: 5),
                        Text(crew.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: OunColors.textMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(Icons.chevron_right,
                      size: 18, color: OunColors.textFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 크루 홈: 상단 무대(크루원 캐릭터) + 피드/크루원/크루 정보 탭. (서버 상세)
/// 무대는 고정 헤더, 아래 탭 콘텐츠만 스크롤.
class CrewHomeScreen extends ConsumerStatefulWidget {
  const CrewHomeScreen({super.key, required this.crewId, required this.name});
  final String crewId;
  final String name; // 로딩 중 표시용 초기 이름

  @override
  ConsumerState<CrewHomeScreen> createState() => _CrewHomeScreenState();
}

class _CrewHomeScreenState extends ConsumerState<CrewHomeScreen> {
  int _tab = 0; // 0: 피드, 1: 크루원, 2: 크루 정보

  static const _stageHeight = 210.0;

  @override
  void initState() {
    super.initState();
    // 크루 상세/피드/가입 신청은 family 프로바이더라 한 번 읽으면 캐시에 남는다.
    // 다시 들어올 때는 그 사이 남이 만든 변화(새 글·가입 신청)를 다시 읽는다.
    // 이미 값이 있을 때만 무효화한다 — 첫 진입에 방금 시작한 요청을 버리고
    // 똑같은 요청을 한 번 더 보내지 않도록. (아직 만들어지지 않은
    // crewJoinRequests는 invalidate가 아무 일도 하지 않는다)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = widget.crewId;
      if (ref.read(crewDetailProvider(id)).hasValue) {
        ref.invalidate(crewDetailProvider(id));
      }
      if (ref.read(crewFeedProvider(id)).hasValue) {
        ref.invalidate(crewFeedProvider(id));
      }
      ref.invalidate(crewJoinRequestsProvider(id));
    });
  }

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
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                          crew.isPublic ? Icons.public : Icons.lock_outline,
                          size: 16,
                          color: OunColors.textFaint),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _stageHeight,
            child: Stack(
              children: [
                if (crew != null)
                  Positioned.fill(
                    bottom: 26,
                    child: CrewStage(members: crew.members),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        crew == null
                            ? '크루원을 불러오는 중…'
                            : '크루원 ${crew.members.length}명이 모여 있어요',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: OunColors.textMuted)),
                  ),
                ),
              ],
            ),
          ),
          // 아래 시트: 탭 + 콘텐츠
          Expanded(
            child: ColoredBox(
              color: OunColors.background,
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
      default:
        return _CrewInfoTab(crew: crew, onLeave: () => _leave(crew));
    }
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['피드', '크루원', '크루 정보'];

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
                crewId: crewId,
                onTap: () async {
                  await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CrewPostDetailScreen(post: p, crewId: crewId),
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

/// 크루원 탭: (방장) 가입 신청 관리 + 멤버 목록 + 초대.
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
      if (context.mounted) {
        OunToast.show(context, '$name님에게 초대를 보냈어요',
            kind: OunToastKind.success);
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
        if (crew.isLeader) _JoinRequestsCard(crew: crew),
        for (final m in crew.members) _MemberRow(m),
        if (crew.isLeader) ...[
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
      ],
    );
  }
}

/// (방장) 대기중 가입 신청 목록 + 승인/거절. 신청이 없으면 아무것도 안 보인다.
class _JoinRequestsCard extends ConsumerWidget {
  const _JoinRequestsCard({required this.crew});
  final CrewDetail crew;

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    CrewJoinRequestItem req,
    bool accept,
  ) async {
    try {
      await ref
          .read(apiClientProvider)
          .respondJoinRequest(crew.id, req.id, accept);
      ref.invalidate(crewJoinRequestsProvider(crew.id));
      if (accept) {
        ref.invalidate(crewDetailProvider(crew.id));
        ref.invalidate(crewsProvider);
      }
      if (context.mounted) {
        OunToast.show(
          context,
          accept ? '${req.displayName}님을 크루원으로 받았어요' : '가입 신청을 거절했어요',
          kind: accept ? OunToastKind.success : OunToastKind.info,
        );
      }
    } catch (_) {
      if (context.mounted) OunToast.show(context, '처리에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(crewJoinRequestsProvider(crew.id)).value ??
        const <CrewJoinRequestItem>[];
    if (reqs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.tabAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('가입 신청 ${reqs.length}건',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: OunColors.tabAccent)),
          const SizedBox(height: 4),
          for (final r in reqs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  PostAvatar(name: r.displayName, nickname: r.nickname, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: OunColors.textPrimary)),
                  ),
                  _miniBtn(
                    label: '거절',
                    filled: false,
                    onTap: () => _respond(context, ref, r, false),
                  ),
                  const SizedBox(width: 6),
                  _miniBtn(
                    label: '수락',
                    filled: true,
                    onTap: () => _respond(context, ref, r, true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniBtn({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? OunColors.tabAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: filled ? OunColors.tabAccent : OunColors.cardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? OunColors.onTabAccent : OunColors.textMuted)),
      ),
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

  Future<void> _editSettings(BuildContext context, WidgetRef ref) async {
    final result = await showCrewEditSheet(
      context,
      initialName: crew.name,
      initialDescription: crew.description ?? '',
      initialIsPublic: crew.isPublic,
    );
    if (result == null) return;
    try {
      await ref.read(apiClientProvider).updateCrew(
            crew.id,
            name: result.name,
            description: result.description ?? '',
            isPublic: result.isPublic,
          );
      ref.invalidate(crewDetailProvider(crew.id));
      ref.invalidate(crewsProvider);
      if (context.mounted) {
        OunToast.show(context, '크루 설정을 저장했어요', kind: OunToastKind.success);
      }
    } catch (_) {
      if (context.mounted) OunToast.show(context, '저장에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(crewRewardsProvider(crew.id)).value ?? [];
    final hasDesc = crew.description != null && crew.description!.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        // 크루 소개 + (방장) 설정 진입
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
                  Icon(crew.isPublic ? Icons.public : Icons.lock_outline,
                      size: 15, color: OunColors.textMuted),
                  const SizedBox(width: 5),
                  Text(crew.isPublic ? '공개 크루' : '비공개 크루',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OunColors.textMuted)),
                  const Spacer(),
                  if (crew.isLeader)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _editSettings(context, ref),
                      child: const Row(
                        children: [
                          Icon(Icons.tune_rounded,
                              size: 15, color: OunColors.tabAccent),
                          SizedBox(width: 4),
                          Text('설정',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: OunColors.tabAccent)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                hasDesc ? crew.description! : '아직 크루 소개가 없어요',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: hasDesc ? OunColors.textPrimary : OunColors.textFaint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
    final isMe = m.isMe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isMe
            ? null // 내 행은 내 홈(홈 탭)이라 별도 이동 없음
            : () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FriendHomeScreen(
                        nickname: m.nickname, displayName: m.displayName),
                  ),
                ),
        // 모든 행의 내부 여백을 동일하게 둬 아바타·이름 시작 위치를 맞춘다.
        // 내 행만 배경 틴트+테두리로 강조한다(레이아웃은 그대로).
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: isMe
              ? BoxDecoration(
                  color: OunColors.tabAccent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: OunColors.tabAccent.withValues(alpha: 0.35)),
                )
              : null,
          child: Row(
            children: [
              PostAvatar(name: m.displayName, nickname: m.nickname, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(m.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  isMe ? FontWeight.w800 : FontWeight.w600,
                              color: OunColors.textPrimary)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      _badge('나', filled: true),
                    ],
                    if (m.isLeader) ...[
                      const SizedBox(width: 6),
                      _badge('방장'),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: isMe ? Colors.transparent : OunColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? OunColors.tabAccent : OunColors.card,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: filled ? OunColors.onTabAccent : OunColors.tabAccent)),
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


/// 크루원들이 나란히 서 있는 무대. 가운데부터 좌우로 번갈아 세우고,
/// 앞뒤로 살짝 엇갈리게 해 모여 있는 느낌을 낸다.
class CrewStage extends StatelessWidget {
  const CrewStage({super.key, required this.members});
  final List<CrewMemberData> members;

  static const _maxShown = 6;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(_maxShown).toList();
    // 0, 1, -1, 2, -2 … 순으로 자리를 배정한다.
    final order = [
      for (var i = 0; i < shown.length; i++)
        i == 0 ? 0 : (i.isOdd ? (i + 1) ~/ 2 : -(i ~/ 2)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final w = h * kCharacterAspect;
        final gap = shown.length <= 1
            ? 0.0
            : ((c.maxWidth - w) / (shown.length - 1)).clamp(0.0, w * 0.62);
        // 뒷줄이 먼저 그려지도록 바깥 자리부터.
        final indices = List.generate(shown.length, (i) => i)
          ..sort((a, b) => order[b].abs().compareTo(order[a].abs()));
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final i in indices)
              Positioned(
                left: c.maxWidth / 2 - w / 2 + order[i] * gap,
                top: order[i].abs().isOdd ? 0 : 6,
                width: w,
                height: h * (order[i].abs().isOdd ? 0.94 : 1.0),
                child: LivingCharacter(
                  look: CharacterLook(gender: shown[i].gender),
                  seed: i + 1,
                ),
              ),
          ],
        );
      },
    );
  }
}
