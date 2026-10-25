import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';
import '../character/character_avatar.dart';
import 'friend_home_screen.dart';

/// 친구 찾기: 닉네임을 치면 맞는 사람이 바로 목록으로 뜨고, 누르면 프로필에서
/// 캐릭터를 보고 친구 추가한다(요청을 바로 보내지 않는다).
class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends ConsumerState<FriendSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    // 글자마다 요청하지 않게 잠깐 멈췄을 때 찾는다.
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _query = _clean(text));
    });
  }

  static String _clean(String text) => text.trim().replaceFirst('@', '');

  /// 확인(엔터): 닉네임이 딱 맞는 사람이 있으면 그 프로필로 간다.
  Future<void> _onSubmitted(String text) async {
    final query = _clean(text);
    if (query.isEmpty) return;
    _debounce?.cancel();
    setState(() => _query = query);
    try {
      final people = await ref.read(userSearchProvider(query).future);
      if (!mounted) return;
      final exact = people.where(
        (p) => p.nickname.toLowerCase() == query.toLowerCase(),
      );
      if (exact.isNotEmpty) {
        _open(exact.first);
      } else if (people.length == 1) {
        _open(people.first);
      } else if (people.isEmpty) {
        OunToast.show(context, '@$query 을(를) 찾지 못했어요');
      }
    } catch (_) {}
  }

  void _open(PersonCard p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(nickname: p.nickname),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('친구 찾기',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
              textInputAction: TextInputAction.search,
              maxLength: 20,
              style:
                  const TextStyle(fontSize: 15, color: OunColors.textPrimary),
              decoration: InputDecoration(
                hintText: '아이디나 닉네임',
                hintStyle: const TextStyle(color: OunColors.textFaint),
                counterText: '',
                prefixText: '@ ',
                prefixStyle:
                    const TextStyle(color: OunColors.tabAccent, fontSize: 15),
                suffixIcon: const Icon(Icons.search_rounded,
                    color: OunColors.textMuted),
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
          ),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _results() {
    if (_query.isEmpty) {
      return const _Hint('친구의 @아이디나 닉네임을 입력해 보세요');
    }
    final async = ref.watch(userSearchProvider(_query));
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
          child: CircularProgressIndicator(color: OunColors.tabAccent)),
      error: (_, _) => const _Hint('찾지 못했어요. 잠시 후 다시 시도해 주세요'),
      data: (people) => people.isEmpty
          ? _Hint('@$_query 와(과) 맞는 사람이 없어요')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _PersonRow(person: people[i], onTap: () => _open(people[i])),
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
      );
}

/// 동그란 얼굴 썸네일: 캐릭터 레이어를 겹친 그림의 머리 쪽만 잘라 보여 준다.
class CharacterBadge extends StatelessWidget {
  const CharacterBadge({super.key, required this.look, this.size = 48});
  final CharacterLook look;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: OunColors.card,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        maxWidth: size * 1.9,
        maxHeight: size * 1.9 / kCharacterAspect,
        alignment: const Alignment(0, -0.62),
        child: CharacterFigure(
          // 목록에서는 효과를 빼고 얼굴만.
          look: CharacterLook(gender: look.gender, equipment: look.equipment),
          shadow: false,
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});
  final PersonCard person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              CharacterBadge(
                look: CharacterLook(
                  gender: person.gender,
                  equipment: person.equipment,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('@${person.nickname}',
                        style: const TextStyle(
                            fontSize: 12, color: OunColors.textMuted)),
                  ],
                ),
              ),
              _RelationChip(relation: person.relation),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: OunColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationChip extends StatelessWidget {
  const _RelationChip({required this.relation});
  final String relation;

  @override
  Widget build(BuildContext context) {
    final label = switch (relation) {
      'friend' => '친구',
      'requested' => '요청 보냄',
      'incoming' => '요청 받음',
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: relation == 'incoming'
            ? OunColors.tabAccent.withValues(alpha: 0.14)
            : OunColors.card,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: relation == 'incoming'
                  ? OunColors.tabAccent
                  : OunColors.textMuted)),
    );
  }
}

/// 사람 프로필: 캐릭터와 이름을 보고 친구 추가(관계에 따라 버튼이 바뀐다).
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.nickname});
  final String nickname;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _busy = false;

  Future<void> _act(PersonCard p) async {
    if (_busy) return;
    if (p.relation == 'friend') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FriendHomeScreen(
            nickname: p.nickname,
            displayName: p.displayName,
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final api = ref.read(apiClientProvider);
    try {
      String message;
      if (p.relation == 'incoming') {
        await api.respondFriendRequest(p.requestId!, true);
        message = '${p.displayName}님과 친구가 되었어요';
      } else {
        final (status, name) = await api.sendFriendRequest(p.nickname);
        message = status == 'accepted'
            ? '$name님과 친구가 되었어요'
            : '$name님에게 친구 요청을 보냈어요';
      }
      ref.invalidate(userProfileProvider(p.nickname));
      ref.invalidate(userSearchProvider);
      invalidateAll(ref, [friendsProvider, friendRequestsProvider]);
      if (mounted) {
        OunToast.show(context, message, kind: OunToastKind.success);
      }
    } catch (e) {
      if (mounted) {
        OunToast.show(context, apiErrorMessage(e, '친구 요청에 실패했어요'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userProfileProvider(widget.nickname));
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
      ),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
            child: CircularProgressIndicator(color: OunColors.tabAccent)),
        error: (e, _) => Center(
          child: Text(apiErrorMessage(e, '프로필을 불러오지 못했어요'),
              style: const TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          children: [
            // 캐릭터 무대
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: OunColors.card,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: LivingCharacter(
                look: CharacterLook(
                  gender: p.gender,
                  equipment: p.equipment,
                  specialFx: p.specialFx,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(p.displayName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: OunColors.textPrimary)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('@${p.nickname}',
                  style: const TextStyle(
                      fontSize: 13, color: OunColors.textMuted)),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Pill('지구력 Lv.${p.level ?? 1}'),
                const SizedBox(width: 8),
                _Pill('연속 ${p.streakCurrent ?? 0}일'),
              ],
            ),
            const SizedBox(height: 24),
            _ActionButton(person: p, busy: _busy, onPressed: () => _act(p)),
            if (p.relation == 'none' || p.relation == 'requested') ...[
              const SizedBox(height: 10),
              const Center(
                child: Text('친구가 되면 서로의 운동 기록을 보고 응원할 수 있어요',
                    style:
                        TextStyle(fontSize: 11.5, color: OunColors.textFaint)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: OunColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.person,
    required this.busy,
    required this.onPressed,
  });
  final PersonCard person;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (label, icon, enabled) = switch (person.relation) {
      'friend' => ('친구 홈 보기', Icons.home_rounded, true),
      'incoming' => ('친구 요청 수락', Icons.how_to_reg_rounded, true),
      'requested' => ('요청을 보냈어요', Icons.schedule_rounded, false),
      'me' => ('나예요', Icons.person_rounded, false),
      _ => ('친구 추가', Icons.person_add_alt_1_rounded, true),
    };
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: OunColors.tabAccent,
        foregroundColor: OunColors.onTabAccent,
        disabledBackgroundColor: OunColors.card,
        disabledForegroundColor: OunColors.textMuted,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: enabled && !busy ? onPressed : null,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: OunColors.onTabAccent))
          : Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }
}
