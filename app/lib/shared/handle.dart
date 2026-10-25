import 'package:flutter/services.dart';

/// @아이디 규칙(서버 backend/src/users/handle.ts와 같다): 영문 소문자·숫자·
/// 밑줄·마침표 3~20자, 마침표로 시작·끝나거나 연속될 수 없다. 가입 후 변경 불가.
final handlePattern = RegExp(r'^(?!\.)(?!.*\.\.)[a-z0-9_.]{3,20}(?<!\.)$');

bool isValidHandle(String v) => handlePattern.hasMatch(v.trim());

/// 입력하는 동안 소문자로 바꾸고 허용되지 않는 글자는 걸러 낸다.
class HandleInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
