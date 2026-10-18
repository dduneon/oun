import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/api/models.dart';
import '../../theme/app_theme.dart';
import 'character_avatar.dart';

/// 서버 mood를 홈 캐릭터의 평상시 표정과 말풍선 대사로 옮긴다.
/// 착한 게이미피케이션: 오래 쉬어도 귀여운 시무룩까지만, 탓하는 말은 하지 않는다.
class MoodLook {
  const MoodLook(this.face, this.lines);

  final CharacterFace face;
  final List<String> lines;

  static MoodLook of(CharacterMoodState? m) {
    if (m == null) return const MoodLook(CharacterFace.normal, []);
    if (m.restingToday) {
      return const MoodLook(CharacterFace.sleepy, [
        '오늘은 푹 쉬는 날이에요 zZ',
        '쉬는 것도 운동의 일부래요',
        '내일 더 가볍게 움직여요!',
      ]);
    }
    return switch (m.mood) {
      'energetic' => const MoodLook(CharacterFace.normal, [
        '방금 운동해서 힘이 펄펄 나요!',
        '오늘 정말 멋졌어요 ✨',
        '몸이 가벼워진 것 같아요!',
      ]),
      'happy' => const MoodLook(CharacterFace.normal, [
        '오늘도 기분 좋아요 ♪',
        '요즘 우리 꾸준하다!',
        '같이 있어서 좋아요',
      ]),
      'hungry' => const MoodLook(CharacterFace.hungry, [
        '배가 꼬르륵… 조금 걸어 볼까요?',
        '몸이 근질근질해요',
        '10분만 같이 움직여 볼래요?',
      ]),
      'sleepy' => const MoodLook(CharacterFace.sleepy, [
        'zZ… 앗, 다시 왔군요!',
        '천천히 다시 시작해 봐요',
        '기다리고 있었어요',
      ]),
      _ => const MoodLook(CharacterFace.normal, [
        '오늘은 뭐 하고 놀까요?',
        '가볍게 스트레칭부터 어때요?',
        '오늘도 나만의 속도로!',
      ]),
    };
  }

  /// 대사 하나. [turn]이 바뀔 때마다 다음 대사로 넘어간다.
  String line(int turn) => lines[turn % lines.length];

  /// 처음 보여 줄 대사 순번(매번 같은 말로 시작하지 않게).
  static int randomTurn() => math.Random().nextInt(1 << 16);
}

/// 캐릭터 머리 위에 잠깐 떴다 사라지는 말풍선.
class MoodBubble extends StatelessWidget {
  const MoodBubble({super.key, required this.text, required this.visible});

  final String text;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: AnimatedScale(
          scale: visible ? 1 : 0.9,
          alignment: Alignment.bottomCenter,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: OunColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OunColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: OunColors.textPrimary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary,
                  ),
                ),
              ),
              // 말꼬리
              Transform.translate(
                offset: const Offset(0, -5),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: OunColors.surface,
                      border: Border(
                        right: BorderSide(color: OunColors.cardBorder),
                        bottom: BorderSide(color: OunColors.cardBorder),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
