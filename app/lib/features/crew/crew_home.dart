import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../../unity/unity_stage.dart';
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

/// 크루 홈: 상단 라이브 3D 무대(크루원 캐릭터) + 피드/크루원/크루 정보 탭. (서버 상세)
///
/// 진입 즉시 전역 Unity 뷰를 크루 씬으로 전환해 무대 영역(투명)으로
/// 캐릭터들이 비쳐 보인다. 무대는 고정 헤더, 아래 탭 콘텐츠만 스크롤.
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
  final _stageKey = GlobalKey();
  String? _spawnedTokens; // 무대에 이미 스폰한 토큰(중복 전환 방지)
  // 이 화면을 감싸는 두 전환 애니메이션.
  //  - primary(animation): 이 화면 자신의 진입/복귀 슬라이드
  //  - secondary(secondaryAnimation): 위에 다른 화면(댓글 등)이 덮일 때의 밀림
  // 둘 중 하나라도 진행 중이면 무대 박스에 transform이 걸려 좌표가 밀린다.
  Animation<double>? _primaryAnim;
  Animation<double>? _secondaryAnim;
  bool _revealed = false; // 무대 공개 여부(false면 불투명 덮개로 Unity를 가림).

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final primary = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (primary != _primaryAnim) {
      _primaryAnim?.removeStatusListener(_onRouteAnim);
      _primaryAnim = primary;
      _primaryAnim?.addStatusListener(_onRouteAnim);
    }
    if (secondary != _secondaryAnim) {
      _secondaryAnim?.removeStatusListener(_onRouteAnim);
      _secondaryAnim = secondary;
      _secondaryAnim?.addStatusListener(_onRouteAnim);
    }
    _refreshSettled();
  }

  /// 완전 안착 = 진입 전환이 끝났고(primary) 위를 덮은 화면도 없다(secondary).
  /// 이때만 무대 박스가 transform 없이 최종 위치에 있으므로 측정이 안전하다.
  bool get _pageSettled {
    final primaryDone = _primaryAnim == null || _primaryAnim!.isCompleted;
    final secondaryIdle = _secondaryAnim == null || _secondaryAnim!.isDismissed;
    return primaryDone && secondaryIdle;
  }

  /// 이 화면이 빠져나가는 중(복귀 슬라이드가 뒤로 진행/종료)인지.
  bool get _isLeaving {
    final p = _primaryAnim;
    return p != null &&
        (p.status == AnimationStatus.reverse ||
            p.status == AnimationStatus.dismissed);
  }

  void _onRouteAnim(AnimationStatus _) => _refreshSettled();

  /// 어떤 전환이든(진입·복귀·덮임·열림) 상태가 바뀔 때 호출.
  /// 원칙: 전환·이탈 중엔 무대를 즉시 덮고, 완전 안착했을 때만 rect를 먼저
  /// 적용한 뒤 다음 프레임에 공개해 검은 프레임이 새지 않게 한다.
  /// (crew→home 씬 교체 자체는 UnityHost의 준비-완료 가림막이 숨기므로 여기선
  ///  씬을 건드리지 않는다. 이탈 중엔 크루 씬을 그대로 두고 덮어만 둔다.)
  void _refreshSettled() {
    if (!mounted) return;

    // 진입 중·덮임/열림 중·이탈 중: 그냥 덮어둔다.
    if (!_pageSettled || _isLeaving) {
      if (_revealed) setState(() => _revealed = false);
      return;
    }

    // 완전 안착: rect를 먼저 적용하고(덮인 상태 유지), 그 다음 프레임에 공개한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLeaving || !_pageSettled) return;
      _syncStageViewport();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLeaving && _pageSettled && !_revealed) {
          setState(() => _revealed = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _primaryAnim?.removeStatusListener(_onRouteAnim);
    _secondaryAnim?.removeStatusListener(_onRouteAnim);
    super.dispose();
  }

  /// 크루원 목록이 로드되면 캐릭터 토큰으로 Unity 크루 씬을 전환한다.
  void _syncUnity(CrewDetail detail) {
    final tokens = detail.members.map((m) => m.charToken).join(',');
    if (tokens == _spawnedTokens) return;
    _spawnedTokens = tokens;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unitySceneProvider.notifier).showCrew(tokens);
      _syncStageViewport();
    });
  }

  /// 무대 박스의 화면상 위치를 재서 Unity 뷰를 그 영역에만 렌더하게 한다.
  /// 전환(진입이든 덮임이든) 도중이면 좌표가 밀리므로 재지 않는다(안착 후 다시 불린다).
  void _syncStageViewport() {
    if (!mounted || !_pageSettled) return;
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final size = Size(box.size.width, box.size.height + 28);
    ref.read(unityViewportProvider.notifier).setRect(origin & size);
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
    if (crew != null) _syncUnity(crew);

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
          // 라이브 3D 무대(투명 창): Unity 뷰를 이 박스 크기에 맞춰 렌더한다.
          SizedBox(
            key: _stageKey,
            height: _stageHeight,
            child: Stack(
              children: [
                // 전환 중엔 불투명 배경으로 무대 구멍을 막아 아래 화면(과 Unity의
                // rect 변경/씬 전환 순간)이 비치지 않게 하고, 안착 후에만 페이드로
                // 무대를 드러낸다. 덮을 땐 즉시(duration 0), 열 땐 부드럽게.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _revealed ? 0 : 1,
                      duration: _revealed
                          ? const Duration(milliseconds: 240)
                          : Duration.zero,
                      child: const ColoredBox(color: OunColors.background),
                    ),
                  ),
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
          // 아래 시트: 탭 + 콘텐츠 (불투명 → Unity 가림)
          // ColoredBox로 뒤를 불투명하게 받쳐, 둥근 상단 모서리 틈으로 Unity가
          // 비쳐 전환 중 좌하·우하가 검게 깜빡이는 것을 막는다(정착 시엔 Unity
          // 배경과 같은 색이라 티가 나지 않는다).
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
