import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/shared/handle.dart';

void main() {
  test('@아이디는 영문 소문자·숫자·_ . 3~20자, 마침표로 시작·끝·연속 불가', () {
    for (final ok in ['oun', 'run_er.2026', 'a_b', 'abcdefghij0123456789']) {
      expect(isValidHandle(ok), isTrue, reason: ok);
    }
    for (final bad in [
      'ab',
      'Runner',
      '오운러버',
      'has space',
      '.dot',
      'dot.',
      'a..b',
      'abcdefghij01234567890',
    ]) {
      expect(isValidHandle(bad), isFalse, reason: bad);
    }
  });

  test('입력하는 동안 소문자로 바꾸고 허용되지 않는 글자는 지운다', () {
    final out = HandleInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'Oun 러너_Run.1!'),
    );
    expect(out.text, 'oun_run.1');
  });
}
