import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';
import 'crew_create_sheet.dart';
import 'crew_discover.dart';
import 'crew_feed.dart';
import 'crew_home.dart';
import 'friend_home_screen.dart';

/// 소셜 탭: 상단 세그먼트로 친구 / 크루 통합. 랭킹 없이 응원 중심. (서버)
class CrewScreen extends ConsumerStatefulWidget {
  const CrewScreen({super.key});

  @override
  ConsumerState<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends ConsumerState<CrewScreen> {
  int _segment = 0; // 0: 친구, 1: 크루

  Future<void> _createCrew() async {
    final result = await showCrewCreateSheet(context);
    if (result == null) return;
    try {
      final crew = await ref.read(apiClientProvider).createCrew(
            result.name,
            description: result.description,
            isPublic: result.isPublic,
          );
      ref.invalidate(crewsProvider);
      if (mounted) {
        OunToast.show(context, '${crew.name} 크루를 만들었어요',
            kind: OunToastKind.success);
      }
    } catch (_) {
      if (mounted) OunToast.show(context, '크루 생성에 실패했어요');
    }
  }

  void _openDiscover() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const CrewDiscoverScreen()),
    );
  }

  Future<void> _addFriend() async {
    final nickname = await showNicknameInputSheet(
      context,
      title: '친구 요청 보내기',
      hint: '@닉네임 입력',
      action: '요청',
    );
    if (nickname == null || nickname.isEmpty) return;
    try {
      final (status, name) =
          await ref.read(apiClientProvider).sendFriendRequest(nickname);
      if (status == 'accepted') {
        ref.invalidate(friendsProvider);
        ref.invalidate(friendRequestsProvider);
      }
      if (mounted) {
        OunToast.show(
          context,
          status == 'accepted'
              ? '$name님과 친구가 되었어요'
              : '$name님에게 친구 요청을 보냈어요',
          kind: OunToastKind.success,
        );
      }
    } catch (_) {
      if (mounted) {
        OunToast.show(context, '친구 요청에 실패했어요. 닉네임을 확인해 주세요');
      }
    }
  }

  Future<void> _openCrew(CrewCardData crew) async {
    // 크루 홈은 진입 시 Unity를 크루 씬으로 바꾼다. 여기서 홈으로 되돌리지는
    // 않는다 — 불투명한 소셜 탭 위에서 rect를 바꾸면 플랫폼 뷰가 한 프레임
    // 삐져나오기 때문. 홈 복귀는 홈 탭이 보일 때 MainScaffold가 처리한다.
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => CrewHomeScreen(crewId: crew.id, name: crew.name),
      ),
    );
    ref.invalidate(crewsProvider);
  }

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
        if (_segment == 0) _friendsSection() else _crewsSection(),
      ],
    );
  }

  Widget _friendsSection() {
    final async = ref.watch(friendsProvider);
    return Column(
      children: [
        const _FriendRequestsSection(),
        // 친구 추가 진입점
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: OunColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: OunColors.cardBorder),
            ),
            child: InkWell(
              onTap: _addFriend,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt,
                        size: 17, color: OunColors.textMuted),
                    SizedBox(width: 8),
                    Text('@닉네임으로 친구 요청',
                        style:
                            TextStyle(fontSize: 13, color: OunColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: OunColors.tabAccent))),
          ),
          error: (_, _) => const _ErrorHint('친구 목록을 불러오지 못했어요'),
          data: (friends) {
            if (friends.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text('아직 친구가 없어요 · @닉네임으로 추가해 보세요',
                      style: TextStyle(
                          fontSize: 12.5, color: OunColors.textFaint)),
                ),
              );
            }
            return Column(
              children: [for (final f in friends) _FriendRow(f)],
            );
          },
        ),
      ],
    );
  }

  Widget _crewsSection() {
    final async = ref.watch(crewsProvider);
    return Column(
      children: [
        _InvitationsSection(onChanged: () => ref.invalidate(crewsProvider)),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
                child: CircularProgressIndicator(color: OunColors.tabAccent)),
          ),
          error: (_, _) => const _ErrorHint('크루를 불러오지 못했어요'),
          data: (crews) {
            if (crews.isEmpty) return _crewEmpty();
            return Column(
              children: [
                for (final c in crews)
                  CrewCard(crew: c, onTap: () => _openCrew(c)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _outlineAction(
                        icon: Icons.travel_explore_rounded,
                        label: '크루 찾기',
                        onTap: _openDiscover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _outlineAction(
                        icon: Icons.add_rounded,
                        label: '새 크루 만들기',
                        onTap: _createCrew,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: OunColors.tabAccent),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OunColors.tabAccent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crewEmpty() => Padding(
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
            const Text('크루를 찾아 가입 신청하거나 직접 만들어 보세요',
                style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OunColors.tabAccent,
                    side: const BorderSide(color: OunColors.cardBorder),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _openDiscover,
                  icon: const Icon(Icons.travel_explore_rounded, size: 18),
                  label: const Text('크루 찾기',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OunColors.tabAccent,
                    foregroundColor: OunColors.onTabAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _createCrew,
                  child: const Text('크루 만들기',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      );
}

/// 받은 크루 초대 배너. 있을 때만 노출되고, 수락/거절할 수 있다.
class _InvitationsSection extends ConsumerWidget {
  const _InvitationsSection({required this.onChanged});
  final VoidCallback onChanged;

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    CrewInvitation inv,
    bool accept,
  ) async {
    try {
      await ref.read(apiClientProvider).respondCrewInvitation(inv.id, accept);
      ref.invalidate(crewInvitationsProvider);
      onChanged();
      if (context.mounted) {
        OunToast.show(
          context,
          accept ? '${inv.crewName} 크루에 가입했어요' : '초대를 거절했어요',
          kind: accept ? OunToastKind.success : OunToastKind.info,
        );
      }
    } catch (_) {
      if (context.mounted) OunToast.show(context, '처리에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crewInvitationsProvider);
    final invites = async.value ?? const <CrewInvitation>[];
    if (invites.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 8),
            child: Text('받은 초대',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: OunColors.textMuted)),
          ),
          for (final inv in invites)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: OunColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: OunColors.tabAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined,
                          size: 17, color: OunColors.tabAccent),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${inv.crewName} 크루 초대',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: OunColors.textPrimary),
                        ),
                      ),
                      Text('멤버 ${inv.memberCount}명',
                          style: const TextStyle(
                              fontSize: 11, color: OunColors.textFaint)),
                    ],
                  ),
                  if (inv.crewDescription != null &&
                      inv.crewDescription!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(inv.crewDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: OunColors.textMuted)),
                  ],
                  if (inv.invitedByName != null) ...[
                    const SizedBox(height: 4),
                    Text('${inv.invitedByName}님이 초대했어요',
                        style: const TextStyle(
                            fontSize: 11, color: OunColors.textFaint)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: OunColors.textMuted,
                            side: const BorderSide(color: OunColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _respond(context, ref, inv, false),
                          child: const Text('거절',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OunColors.tabAccent,
                            foregroundColor: OunColors.onTabAccent,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _respond(context, ref, inv, true),
                          child: const Text('수락',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 받은 친구 요청 목록 + 수락/거절. 요청이 없으면 아무것도 안 보인다.
class _FriendRequestsSection extends ConsumerWidget {
  const _FriendRequestsSection();

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    FriendRequestItem req,
    bool accept,
  ) async {
    try {
      await ref.read(apiClientProvider).respondFriendRequest(req.id, accept);
      ref.invalidate(friendRequestsProvider);
      if (accept) ref.invalidate(friendsProvider);
      if (context.mounted) {
        OunToast.show(
          context,
          accept ? '${req.displayName}님과 친구가 되었어요' : '친구 요청을 거절했어요',
          kind: accept ? OunToastKind.success : OunToastKind.info,
        );
      }
    } catch (_) {
      if (context.mounted) OunToast.show(context, '처리에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(friendRequestsProvider).value ??
        const <FriendRequestItem>[];
    if (reqs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.tabAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('받은 친구 요청 ${reqs.length}건',
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: avatarColor(r.nickname), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initialOf(r.displayName),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: OunColors.textPrimary)),
                  ),
                  _miniBtn('거절', false, () => _respond(context, ref, r, false)),
                  const SizedBox(width: 6),
                  _miniBtn('수락', true, () => _respond(context, ref, r, true)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, bool filled, VoidCallback onTap) {
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

class _ErrorHint extends StatelessWidget {
  const _ErrorHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(text,
              style:
                  const TextStyle(fontSize: 12.5, color: OunColors.textFaint)),
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

class _FriendRow extends ConsumerWidget {
  const _FriendRow(this.friend);
  final Friend friend;

  void _openFriendHome(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendHomeScreen(
            nickname: friend.nickname, displayName: friend.displayName),
      ),
    );
  }

  Future<void> _cheer(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).cheer(friend.nickname, emoji: '👏');
      ref.invalidate(friendsProvider);
      ref.invalidate(questsProvider);
      if (context.mounted) {
        OunToast.show(context, '${friend.displayName}님에게 응원을 보냈어요',
            kind: OunToastKind.cheer);
      }
    } catch (_) {
      if (context.mounted) OunToast.show(context, '응원에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  PostAvatar(
                      name: friend.displayName,
                      nickname: friend.nickname,
                      size: 40),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friend.displayName,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: OunColors.textPrimary)),
                        Text(friendActivityLine(friend),
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
              for (final r in friend.reactions)
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
                    onTap: () => _cheer(context, ref),
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
