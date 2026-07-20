import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 피드 목록의 글 카드. (서버 CrewPostData)
class CrewPostCard extends ConsumerStatefulWidget {
  const CrewPostCard({super.key, required this.post, required this.onTap});
  final CrewPostData post;
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
                if (w?.hasPhoto ?? false) ...[
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
  const CrewPostDetailScreen({super.key, required this.post});
  final CrewPostData post;

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
                if (w?.hasPhoto ?? false) ...[
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
