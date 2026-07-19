import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 피드 댓글 하나.
class CrewComment {
  CrewComment({
    required this.initial,
    required this.color,
    required this.name,
    required this.text,
    required this.when,
  });
  final String initial;
  final Color color;
  final String name;
  final String text;
  final String when;
}

/// 크루 피드 글 하나: 운동 기록 공유 + 한마디 + 인증 사진 + 응원/댓글.
class CrewPost {
  CrewPost({
    required this.initial,
    required this.color,
    required this.name,
    required this.when,
    required this.icon,
    required this.workout,
    this.message,
    this.hasPhoto = false,
    this.cheers = 0,
    required this.details,
    required this.comments,
  });

  final String initial;
  final Color color;
  final String name;
  final String when;
  final IconData icon;
  final String workout; // 예: '러닝 5.2km'
  final String? message;
  final bool hasPhoto;
  int cheers;
  bool cheered = false;

  /// 기록 등록 시 입력한 상세(라벨, 값). 상세 화면에서 그대로 보여준다.
  final List<(String, String)> details;
  final List<CrewComment> comments;
}

/// 목데이터 피드. 실제로는 기록 저장 시 '크루에 공유'로 쌓인다.
List<CrewPost> demoCrewPosts() => [
      CrewPost(
        initial: '지',
        color: const Color(0xFFC9865B),
        name: '지민',
        when: '30분 전',
        icon: Icons.directions_run,
        workout: '러닝 5.2km',
        message: '오늘 한강 뛰었어요 🌊 날씨 완전 좋음',
        hasPhoto: true,
        cheers: 4,
        details: [
          ('종목', '러닝'),
          ('거리', '5.2 km'),
          ('시간', '32분'),
          ('페이스', "6'09\""),
        ],
        comments: [
          CrewComment(
              initial: '현',
              color: const Color(0xFF7FA98C),
              name: '현우',
              text: '오 페이스 좋다 👏 다음엔 같이 뛰자',
              when: '12분 전'),
          CrewComment(
              initial: '서',
              color: const Color(0xFFB58BB0),
              name: '서연',
              text: '한강 코스 어디예요? 저도 갈래요',
              when: '5분 전'),
        ],
      ),
      CrewPost(
        initial: '현',
        color: const Color(0xFF7FA98C),
        name: '현우',
        when: '2시간 전',
        icon: Icons.fitness_center,
        workout: '웨이트 · 하체',
        cheers: 3,
        details: [
          ('종목', '웨이트'),
          ('부위', '하체'),
          ('세트', '5세트'),
          ('시간', '48분'),
        ],
        comments: [
          CrewComment(
              initial: '지',
              color: const Color(0xFFC9865B),
              name: '지민',
              text: '하체 데이 고생했어 🔥',
              when: '1시간 전'),
        ],
      ),
      CrewPost(
        initial: '서',
        color: const Color(0xFFB58BB0),
        name: '서연',
        when: '어제',
        icon: Icons.directions_walk,
        workout: '걷기 8,200보',
        message: '퇴근하고 한 바퀴 🚶‍♀️',
        cheers: 5,
        details: [
          ('종목', '걷기'),
          ('걸음 수', '8,200보'),
          ('시간', '58분'),
        ],
        comments: [],
      ),
    ];

/// 피드 목록의 글 카드.
class CrewPostCard extends StatefulWidget {
  const CrewPostCard({super.key, required this.post, required this.onTap});
  final CrewPost post;
  final VoidCallback onTap;

  @override
  State<CrewPostCard> createState() => _CrewPostCardState();
}

class _CrewPostCardState extends State<CrewPostCard> {
  @override
  Widget build(BuildContext context) {
    final p = widget.post;
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
                    _Avatar(initial: p.initial, color: p.color, size: 34),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: OunColors.textPrimary)),
                          Text(p.when,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: OunColors.textFaint)),
                        ],
                      ),
                    ),
                    _WorkoutChip(icon: p.icon, label: p.workout),
                  ],
                ),
                if (p.message != null) ...[
                  const SizedBox(height: 9),
                  Text(p.message!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: OunColors.textPrimary)),
                ],
                if (p.hasPhoto) ...[
                  const SizedBox(height: 9),
                  const _PhotoPlaceholder(height: 110),
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
                      _CheerButton(
                        cheered: p.cheered,
                        count: p.cheers,
                        onTap: () => setState(() {
                          p.cheered = !p.cheered;
                          p.cheers += p.cheered ? 1 : -1;
                        }),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.mode_comment_outlined,
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

/// 글 상세: 기록 등록 시 입력한 상세 + 댓글 스레드 + 입력창.
class CrewPostDetailScreen extends StatefulWidget {
  const CrewPostDetailScreen({super.key, required this.post});
  final CrewPost post;

  @override
  State<CrewPostDetailScreen> createState() => _CrewPostDetailScreenState();
}

class _CrewPostDetailScreenState extends State<CrewPostDetailScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.post.comments.add(CrewComment(
        initial: '나',
        color: OunColors.tabAccent,
        name: '나',
        text: text,
        when: '방금',
      ));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: Text('${p.name}님의 기록',
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
                    _Avatar(initial: p.initial, color: p.color, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: OunColors.textPrimary)),
                          Text(p.when,
                              style: const TextStyle(
                                  fontSize: 11, color: OunColors.textFaint)),
                        ],
                      ),
                    ),
                    _WorkoutChip(icon: p.icon, label: p.workout),
                  ],
                ),
                if (p.message != null) ...[
                  const SizedBox(height: 12),
                  Text(p.message!,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: OunColors.textPrimary)),
                ],
                if (p.hasPhoto) ...[
                  const SizedBox(height: 12),
                  const _PhotoPlaceholder(height: 180),
                ],
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
                      for (var i = 0; i < p.details.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(p.details[i].$1,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: OunColors.textMuted)),
                            const Spacer(),
                            Text(p.details[i].$2,
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    _CheerButton(
                      cheered: p.cheered,
                      count: p.cheers,
                      onTap: () => setState(() {
                        p.cheered = !p.cheered;
                        p.cheers += p.cheered ? 1 : -1;
                        if (p.cheered) {
                          OunToast.show(context, '${p.name}님에게 응원을 보냈어요',
                              kind: OunToastKind.cheer);
                        }
                      }),
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
  final CrewComment c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(initial: c.initial, color: c.color, size: 30),
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
                          text: c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: '  '),
                      TextSpan(text: c.text),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(c.when,
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

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.initial, required this.color, required this.size});
  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(initial,
            style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      );
}

class _WorkoutChip extends StatelessWidget {
  const _WorkoutChip({required this.icon, required this.label});
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

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.height});
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

class _CheerButton extends StatelessWidget {
  const _CheerButton(
      {required this.cheered, required this.count, required this.onTap});
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
