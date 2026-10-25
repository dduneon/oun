import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../theme/app_theme.dart';
import 'crew_feed.dart';

/// 크루원 초대: 내 친구 목록에서 골라 보낸다. 친구가 아닌 사람은
/// 아래 '닉네임으로 초대하기'로 보낸다([onInviteByNickname]).
Future<void> showCrewInviteSheet(
  BuildContext context, {
  required CrewDetail crew,
  required VoidCallback onInviteByNickname,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CrewInviteSheet(crew: crew, onInviteByNickname: onInviteByNickname),
  );
}

enum _SendState { sending, sent, failed }

class _CrewInviteSheet extends ConsumerStatefulWidget {
  const _CrewInviteSheet({
    required this.crew,
    required this.onInviteByNickname,
  });
  final CrewDetail crew;
  final VoidCallback onInviteByNickname;

  @override
  ConsumerState<_CrewInviteSheet> createState() => _CrewInviteSheetState();
}

class _CrewInviteSheetState extends ConsumerState<_CrewInviteSheet> {
  // 친구별 보낸 상태. 시트 안 토스트는 시트 뒤에 가려지므로 행에서 바로 보여 준다.
  final _sent = <String, _SendState>{};

  Future<void> _invite(Friend f) async {
    setState(() => _sent[f.nickname] = _SendState.sending);
    try {
      await ref
          .read(apiClientProvider)
          .inviteToCrew(widget.crew.id, f.nickname);
      if (mounted) setState(() => _sent[f.nickname] = _SendState.sent);
    } catch (_) {
      if (mounted) setState(() => _sent[f.nickname] = _SendState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = {for (final m in widget.crew.members) m.nickname};
    final friends = ref.watch(friendsProvider);
    final media = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * .8),
      decoration: const BoxDecoration(
        color: OunColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, media.padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: OunColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            '크루원 초대하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: OunColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '친구를 골라 초대를 보내요',
            style: TextStyle(fontSize: 12, color: OunColors.textMuted),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: friends.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: OunColors.tabAccent,
                    ),
                  ),
                ),
              ),
              error: (_, _) => const _Hint('친구 목록을 불러오지 못했어요'),
              data: (list) {
                if (list.isEmpty) {
                  return const _Hint('아직 친구가 없어요.\n닉네임으로 초대해 보세요.');
                }
                // 아직 크루원이 아닌 친구를 위로.
                final sorted = [...list]
                  ..sort((a, b) {
                    final am = members.contains(a.nickname) ? 1 : 0;
                    final bm = members.contains(b.nickname) ? 1 : 0;
                    return am - bm;
                  });
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final f = sorted[i];
                    return _FriendRow(
                      friend: f,
                      isMember: members.contains(f.nickname),
                      state: _sent[f.nickname],
                      onInvite: () => _invite(f),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: OunColors.textMuted),
              onPressed: () {
                Navigator.pop(context);
                widget.onInviteByNickname();
              },
              icon: const Icon(Icons.alternate_email_rounded, size: 16),
              label: const Text(
                '친구가 아닌 사람은 닉네임으로 초대하기',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.isMember,
    required this.state,
    required this.onInvite,
  });
  final Friend friend;
  final bool isMember;
  final _SendState? state;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isMember ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: OunColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: Row(
          children: [
            PostAvatar(
              name: friend.displayName,
              nickname: friend.nickname,
              size: 36,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: OunColors.textPrimary,
                    ),
                  ),
                  Text(
                    '@${friend.nickname}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: OunColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            _action(),
          ],
        ),
      ),
    );
  }

  Widget _action() {
    if (isMember) return const _Tag('크루원');
    return switch (state) {
      _SendState.sending => const SizedBox(
        width: 64,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: OunColors.tabAccent,
            ),
          ),
        ),
      ),
      _SendState.sent => const _Tag('보냈어요', icon: Icons.check_rounded),
      _SendState.failed => _Button('다시 시도', onTap: onInvite),
      null => _Button('초대', onTap: onInvite),
    };
  }
}

class _Button extends StatelessWidget {
  const _Button(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: OunColors.tabAccent,
      foregroundColor: OunColors.onTabAccent,
      minimumSize: const Size(64, 34),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: onTap,
    child: Text(
      label,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: OunColors.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: OunColors.tabAccent),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: OunColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12.5,
        height: 1.5,
        color: OunColors.textMuted,
      ),
    ),
  );
}
