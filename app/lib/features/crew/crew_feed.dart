import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/action_sheet.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/photo_viewer.dart';
import '../../theme/app_theme.dart';

/// 크루 피드 글쓰기 시트를 띄운다. 성공 시 true. 운동 태그는 선택.
Future<bool> showCrewPostComposer(BuildContext context, String crewId) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostComposer(crewId: crewId),
  );
  return ok ?? false;
}

class _PostComposer extends ConsumerStatefulWidget {
  const _PostComposer({required this.crewId});
  final String crewId;

  @override
  ConsumerState<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends ConsumerState<_PostComposer> {
  final _message = TextEditingController();
  String? _taggedId; // 선택한 운동 id (없으면 글만)
  bool _posting = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _canPost =>
      (_message.text.trim().isNotEmpty || _taggedId != null) && !_posting;

  Future<void> _post() async {
    if (!_canPost) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _posting = true);
    try {
      await ref.read(apiClientProvider).createCrewPost(
            widget.crewId,
            workoutLogId: _taggedId,
            message: _message.text.trim(),
          );
      ref.invalidate(crewFeedProvider(widget.crewId));
      ref.invalidate(crewDetailProvider(widget.crewId));
      ref.invalidate(crewsProvider);
      navigator.pop(true);
      OunToast.showWith(messenger, '크루에 공유했어요', kind: OunToastKind.success);
    } catch (_) {
      setState(() => _posting = false);
      OunToast.showWith(messenger, '글 등록에 실패했어요', kind: OunToastKind.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final recent = ref.watch(recentWorkoutsProvider).value ?? const [];
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
            const Text('크루에 글 쓰기',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              onChanged: (_) => setState(() {}),
              maxLength: 300,
              maxLines: 3,
              minLines: 2,
              style:
                  const TextStyle(fontSize: 14, color: OunColors.textPrimary),
              decoration: InputDecoration(
                hintText: '오늘 운동 어땠나요?',
                hintStyle: const TextStyle(color: OunColors.textFaint),
                counterText: '',
                filled: true,
                fillColor: OunColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
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
            const SizedBox(height: 14),
            const Text('운동 기록 태그 (선택)',
                style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const Text('태그할 운동 기록이 아직 없어요',
                  style:
                      TextStyle(fontSize: 12, color: OunColors.textFaint))
            else
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final w = recent[i];
                    final selected = _taggedId == w.id;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                          () => _taggedId = selected ? null : w.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? OunColors.tabAccent
                              : OunColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: selected
                                  ? OunColors.tabAccent
                                  : OunColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                sportIcons[w.sport] ??
                                    Icons.sports_gymnastics,
                                size: 16,
                                color: selected
                                    ? OunColors.onTabAccent
                                    : OunColors.tabAccent),
                            const SizedBox(width: 7),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(workoutChipLabel(w),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? OunColors.onTabAccent
                                            : OunColors.textPrimary)),
                                Text(relativeDay(w.performedAt),
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        color: selected
                                            ? OunColors.onTabAccent
                                            : OunColors.textFaint)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                onPressed: _canPost ? _post : null,
                child: _posting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: OunColors.onTabAccent))
                    : const Text('올리기',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 피드 목록의 글 카드. (서버 CrewPostData)
class CrewPostCard extends ConsumerStatefulWidget {
  const CrewPostCard(
      {super.key,
      required this.post,
      required this.crewId,
      required this.onTap});
  final CrewPostData post;
  final String crewId;
  final VoidCallback onTap;

  @override
  ConsumerState<CrewPostCard> createState() => _CrewPostCardState();
}

class _CrewPostCardState extends ConsumerState<CrewPostCard> {
  Future<void> _toggleCheer() async {
    final p = widget.post;
    try {
      final (cheered, cheers) =
          await ref.read(apiClientProvider).togglePostCheer(p.id);
      setState(() {
        p.cheered = cheered;
        p.cheers = cheers;
      });
    } catch (_) {
      if (mounted) OunToast.show(context, '응원에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final w = p.workout;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: OunColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: OunColors.cardBorder),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PostAvatar(name: p.author.displayName, nickname: p.author.nickname, size: 34),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.author.displayName,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: OunColors.textPrimary)),
                          Text(relativeTime(p.createdAt),
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: OunColors.textFaint)),
                        ],
                      ),
                    ),
                    if (w != null)
                      WorkoutChip(
                          icon: sportIcons[w.sport] ?? Icons.sports_gymnastics,
                          label: workoutChipLabel(w)),
                    if (p.author.isMe)
                      _PostMenu(
                        onEdit: () =>
                            editCrewPostFlow(context, ref, widget.crewId, p),
                        onDelete: () =>
                            deleteCrewPostFlow(context, ref, widget.crewId, p),
                      ),
                  ],
                ),
                if (p.message != null && p.message!.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(p.message!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: OunColors.textPrimary)),
                ],
                if (w?.photoUrl != null) ...[
                  const SizedBox(height: 9),
                  GestureDetector(
                    onTap: () => showPhotoViewer(context, w.photoUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        w!.photoUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const PhotoPlaceholder(height: 180),
                        errorBuilder: (_, _, _) =>
                            const PhotoPlaceholder(height: 180),
                      ),
                    ),
                  ),
                ] else if (w?.hasPhoto ?? false) ...[
                  const SizedBox(height: 9),
                  const PhotoPlaceholder(height: 110),
                ],
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border:
                        Border(top: BorderSide(color: OunColors.cardBorder)),
                  ),
                  child: Row(
                    children: [
                      CheerButton(
                        cheered: p.cheered,
                        count: p.cheers,
                        onTap: _toggleCheer,
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.mode_comment_outlined,
                          size: 15, color: OunColors.textMuted),
                      const SizedBox(width: 5),
                      Text('댓글 ${p.comments.length}',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: OunColors.textMuted)),
                    ],
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

/// 글 상세: 기록 상세 + 댓글 스레드 + 입력창. 댓글은 서버에 저장된다.
class CrewPostDetailScreen extends ConsumerStatefulWidget {
  const CrewPostDetailScreen(
      {super.key, required this.post, required this.crewId});
  final CrewPostData post;
  final String crewId;

  @override
  ConsumerState<CrewPostDetailScreen> createState() =>
      _CrewPostDetailScreenState();
}

class _CrewPostDetailScreenState extends ConsumerState<CrewPostDetailScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment =
          await ref.read(apiClientProvider).commentOnPost(widget.post.id, text);
      setState(() {
        widget.post.comments.add(comment);
        _input.clear();
      });
    } catch (_) {
      if (mounted) OunToast.show(context, '댓글 등록에 실패했어요');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleCheer() async {
    final p = widget.post;
    try {
      final (cheered, cheers) =
          await ref.read(apiClientProvider).togglePostCheer(p.id);
      setState(() {
        p.cheered = cheered;
        p.cheers = cheers;
      });
      if (cheered && mounted) {
        OunToast.show(context, '${p.author.displayName}님에게 응원을 보냈어요',
            kind: OunToastKind.cheer);
      }
    } catch (_) {
      if (mounted) OunToast.show(context, '응원에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final w = p.workout;
    final details = w == null ? const <(String, String)>[] : workoutDetails(w);
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: Text('${p.author.displayName}님의 기록',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
        actions: [
          if (p.author.isMe)
            _PostMenu(
              onEdit: () async {
                if (await editCrewPostFlow(context, ref, widget.crewId, p) &&
                    context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              onDelete: () async {
                if (await deleteCrewPostFlow(context, ref, widget.crewId, p) &&
                    context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              children: [
                Row(
                  children: [
                    PostAvatar(
                        name: p.author.displayName,
                        nickname: p.author.nickname,
                        size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.author.displayName,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: OunColors.textPrimary)),
                          Text(relativeTime(p.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: OunColors.textFaint)),
                        ],
                      ),
                    ),
                    if (w != null)
                      WorkoutChip(
                          icon: sportIcons[w.sport] ?? Icons.sports_gymnastics,
                          label: workoutChipLabel(w)),
                  ],
                ),
                if (p.message != null && p.message!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(p.message!,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: OunColors.textPrimary)),
                ],
                if (w?.photoUrl != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => showPhotoViewer(context, w.photoUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        w!.photoUrl!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const PhotoPlaceholder(height: 220),
                        errorBuilder: (_, _, _) =>
                            const PhotoPlaceholder(height: 220),
                      ),
                    ),
                  ),
                ] else if (w?.hasPhoto ?? false) ...[
                  const SizedBox(height: 12),
                  const PhotoPlaceholder(height: 180),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  // 기록 상세 — 기록 등록 시 입력한 값들
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: OunColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OunColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('기록 상세',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: OunColors.textMuted)),
                        const SizedBox(height: 10),
                        for (var i = 0; i < details.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(details[i].$1,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: OunColors.textMuted)),
                              const Spacer(),
                              Text(details[i].$2,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: OunColors.textPrimary)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    CheerButton(
                      cheered: p.cheered,
                      count: p.cheers,
                      onTap: _toggleCheer,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: OunColors.cardBorder, height: 20),
                Text('댓글 ${p.comments.length}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: OunColors.textPrimary)),
                const SizedBox(height: 4),
                for (final c in p.comments) _CommentRow(c),
                if (p.comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text('첫 댓글로 응원을 남겨보세요',
                          style: TextStyle(
                              fontSize: 12, color: OunColors.textFaint)),
                    ),
                  ),
              ],
            ),
          ),
          // 댓글 입력창
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: OunColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: OunColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _input,
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(
                            fontSize: 13, color: OunColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: '댓글 달기…',
                          hintStyle: TextStyle(color: OunColors.textFaint),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: OunColors.tabAccent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _send,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.send_rounded,
                            size: 18, color: OunColors.onTabAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow(this.c);
  final CrewCommentData c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostAvatar(
              name: c.author.displayName, nickname: c.author.nickname, size: 30),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: OunColors.textPrimary),
                    children: [
                      TextSpan(
                          text: c.author.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: '  '),
                      TextSpan(text: c.text),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(relativeTime(c.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: OunColors.textFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 이니셜 아바타(닉네임 해시 색).
class PostAvatar extends StatelessWidget {
  const PostAvatar(
      {super.key, required this.name, required this.nickname, required this.size});
  final String name;
  final String nickname;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: avatarColor(nickname), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(initialOf(name),
            style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      );
}

class WorkoutChip extends StatelessWidget {
  const WorkoutChip({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: OunColors.card,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: OunColors.tabAccent),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
          ],
        ),
      );
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE7D3BD), Color(0xFFDFC0A2)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_rounded, size: 26, color: Color(0xFFB59677)),
              SizedBox(height: 4),
              Text('운동 인증 사진',
                  style: TextStyle(fontSize: 11, color: Color(0xFFA98F73))),
            ],
          ),
        ),
      );
}

class CheerButton extends StatelessWidget {
  const CheerButton(
      {super.key, required this.cheered, required this.count, required this.onTap});
  final bool cheered;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFD98A88);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cheered ? Icons.favorite_rounded : Icons.favorite_outline,
              size: 15, color: cheered ? rose : OunColors.textMuted),
          const SizedBox(width: 5),
          Text('응원 $count',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cheered ? rose : OunColors.textMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 내 글 수정/삭제
// ─────────────────────────────────────────────────────────────

/// 내 글의 수정/삭제 메뉴(⋮). 탭하면 앱 톤 액션 시트를 연다.
class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showOunActionSheet(context, actions: [
        OunAction(
            label: '수정',
            icon: Icons.edit_outlined,
            onSelected: onEdit),
        OunAction(
            label: '삭제',
            icon: Icons.delete_outline_rounded,
            destructive: true,
            onSelected: onDelete),
      ]),
      child: const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Icon(Icons.more_horiz_rounded,
            size: 19, color: OunColors.textMuted),
      ),
    );
  }
}

/// 내 글 한마디 수정 → 저장. 수정됐으면 true.
Future<bool> editCrewPostFlow(
  BuildContext context,
  WidgetRef ref,
  String crewId,
  CrewPostData post,
) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditPostSheet(
      initial: post.message ?? '',
      hasWorkout: post.workout != null,
    ),
  );
  if (result == null) return false;
  try {
    await ref.read(apiClientProvider).editCrewPost(post.id, result);
    ref.invalidate(crewFeedProvider(crewId));
    if (context.mounted) {
      OunToast.show(context, '글을 수정했어요', kind: OunToastKind.success);
    }
    return true;
  } catch (_) {
    if (context.mounted) OunToast.show(context, '수정에 실패했어요');
    return false;
  }
}

/// 내 글 삭제(확인 후). 삭제됐으면 true.
Future<bool> deleteCrewPostFlow(
  BuildContext context,
  WidgetRef ref,
  String crewId,
  CrewPostData post,
) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: OunColors.background,
      title: const Text('글을 삭제할까요?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: const Text('댓글과 응원도 함께 사라져요.',
          style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소', style: TextStyle(color: OunColors.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('삭제', style: TextStyle(color: Color(0xFFCC4B37))),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await ref.read(apiClientProvider).deleteCrewPost(post.id);
    ref.invalidate(crewFeedProvider(crewId));
    ref.invalidate(crewDetailProvider(crewId));
    ref.invalidate(crewsProvider);
    if (context.mounted) {
      OunToast.show(context, '글을 삭제했어요', kind: OunToastKind.info);
    }
    return true;
  } catch (_) {
    if (context.mounted) OunToast.show(context, '삭제에 실패했어요');
    return false;
  }
}

class _EditPostSheet extends StatefulWidget {
  const _EditPostSheet({required this.initial, required this.hasWorkout});
  final String initial;
  final bool hasWorkout;

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // 운동 태그가 있으면 한마디를 비워도 되지만, 글만이면 내용이 있어야 한다.
    final canSave = widget.hasWorkout || _controller.text.trim().isNotEmpty;
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
            const Text('글 수정',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              maxLength: 300,
              maxLines: 4,
              minLines: 2,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: OunColors.textPrimary),
              decoration: InputDecoration(
                hintText: '한마디를 남겨보세요',
                hintStyle: const TextStyle(color: OunColors.textFaint),
                counterText: '',
                filled: true,
                fillColor: OunColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            const SizedBox(height: 14),
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
                onPressed: canSave
                    ? () => Navigator.of(context).pop(_controller.text.trim())
                    : null,
                child: const Text('저장',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
