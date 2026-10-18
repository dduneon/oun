import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/features/character/character_avatar.dart';
import 'package:oun_app/features/character/character_mood.dart';
import 'package:oun_app/shared/api/models.dart';

void main() {
  CharacterMoodState mood(String m, {bool resting = false}) =>
      CharacterMoodState(mood: m, restingToday: resting);

  test('서버 mood에 맞는 평상시 얼굴을 고른다', () {
    expect(MoodLook.of(mood('energetic')).face, CharacterFace.normal);
    expect(MoodLook.of(mood('hungry')).face, CharacterFace.hungry);
    expect(MoodLook.of(mood('sleepy')).face, CharacterFace.sleepy);
    // 휴식일엔 기분과 상관없이 쉬는 얼굴
    expect(MoodLook.of(mood('happy', resting: true)).face, CharacterFace.sleepy);
    expect(MoodLook.of(null).lines, isEmpty);
  });

  test('말풍선 대사는 순번마다 돌아간다', () {
    final look = MoodLook.of(mood('neutral'));
    expect(look.line(0), isNot(look.line(1)));
    expect(look.line(look.lines.length), look.line(0));
  });

  test('성별에 맞는 기분 얼굴 레이어', () {
    const f = CharacterLook(gender: 'f');
    const m = CharacterLook(gender: 'm');
    expect(f.body(CharacterFace.hungry), 'body_f_hungry');
    expect(m.body(CharacterFace.sleepy), 'body_sleepy');
  });

  test('GET /care 응답을 읽는다', () {
    final care = CareStatus.fromJson({
      'streak': {'current': 5, 'longest': 9},
      'restDay': {
        'today': false,
        'canDeclare': true,
        'blockedReason': null,
        'usedThisWeek': 1,
        'weeklyLimit': 2,
        'reward': 10,
      },
      'protectors': {
        'count': 2,
        'max': 2,
        'every': 7,
        'nextInDays': null,
        'recentProtectedDates': ['2026-10-17'],
      },
    });
    expect(care.canDeclareRest, isTrue);
    expect(care.nextProtectorInDays, isNull);
    expect(care.recentProtectedDates, ['2026-10-17']);
  });
}
