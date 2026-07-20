import 'package:flutter/material.dart';

import 'api/models.dart';

/// 서버 enum ↔ 앱 표시용 매핑·포맷 헬퍼 모음.

const Map<String, String> sportLabels = {
  'running': '러닝',
  'walking': '걷기',
  'weight': '웨이트',
  'cycling': '자전거',
  'yoga': '요가',
  'etc': '기타',
};

const Map<String, IconData> sportIcons = {
  'running': Icons.directions_run,
  'walking': Icons.directions_walk,
  'weight': Icons.fitness_center,
  'cycling': Icons.directions_bike,
  'yoga': Icons.self_improvement,
  'etc': Icons.sports_gymnastics,
};

const Map<String, String> bodyPartLabels = {
  'upper': '상체',
  'lower': '하체',
  'full': '전신',
  'core': '코어',
};

/// 서버가 저장한 아이콘 키 → 머티리얼 아이콘 (퀘스트·업적).
const Map<String, IconData> iconByKey = {
  'check_circle_outline': Icons.check_circle_outline,
  'timer_outlined': Icons.timer_outlined,
  'photo_camera_outlined': Icons.photo_camera_outlined,
  'calendar_month_outlined': Icons.calendar_month_outlined,
  'favorite_outline': Icons.favorite_outline,
  'local_fire_department_outlined': Icons.local_fire_department_outlined,
  'local_fire_department': Icons.local_fire_department,
  'directions_walk': Icons.directions_walk,
  'wb_twilight': Icons.wb_twilight,
  'photo_camera': Icons.photo_camera,
  'calendar_month': Icons.calendar_month,
  'directions_run': Icons.directions_run,
  'fitness_center': Icons.fitness_center,
  'groups': Icons.groups,
  'favorite': Icons.favorite,
  'checkroom': Icons.checkroom,
  'nightlight_round': Icons.nightlight_round,
  'emoji_events': Icons.emoji_events,
};

IconData iconFor(String? key, {IconData fallback = Icons.flag_outlined}) =>
    iconByKey[key] ?? fallback;

/// 1234 → '1,234'
String comma(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// '#RRGGBB' → Color. 실패 시 카드 톤.
Color colorFromHex(String? hex, {Color fallback = const Color(0xFFD9C7B2)}) {
  if (hex == null) return fallback;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// 상대 시각: 방금/분 전/시간 전/어제/n일 전.
String relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  final days = DateTime.now().difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days <= 1) return '어제';
  return '$days일 전';
}

/// 날짜만: 오늘/어제/n일 전.
String relativeDay(DateTime t) {
  final now = DateTime.now();
  final days =
      DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days <= 0) return '오늘';
  if (days == 1) return '어제';
  return '$days일 전';
}

/// 운동 주 지표 텍스트: '5.2km' / '8,200보' / '상체 5세트' / '32분'.
String workoutMetric(Workout w) {
  if (w.distanceM != null) return '${(w.distanceM! / 1000).toStringAsFixed(1)}km';
  if (w.steps != null) return '${comma(w.steps!)}보';
  if (w.bodyPart != null) {
    final part = bodyPartLabels[w.bodyPart] ?? w.bodyPart!;
    return w.sets != null ? '$part ${w.sets}세트' : part;
  }
  return '${w.minutes}분';
}

/// 피드 칩 라벨: '러닝 5.2km' / '웨이트 · 하체'.
String workoutChipLabel(Workout w) {
  final label = sportLabels[w.sport] ?? w.sport;
  if (w.distanceM != null) return '$label ${(w.distanceM! / 1000).toStringAsFixed(1)}km';
  if (w.steps != null) return '$label ${comma(w.steps!)}보';
  if (w.bodyPart != null) return '$label · ${bodyPartLabels[w.bodyPart] ?? w.bodyPart}';
  return '$label ${w.minutes}분';
}

/// 친구 행 활동 문구: '러닝 5.2km · 오늘 완료'.
String friendActivityLine(Friend f) {
  final w = f.latestWorkout;
  if (w == null) return '아직 기록이 없어요';
  return '${workoutChipLabel(w)} · ${relativeDay(w.performedAt)}';
}

/// 기록 상세 (라벨, 값) 목록 — 피드 상세 화면.
List<(String, String)> workoutDetails(Workout w) {
  final rows = <(String, String)>[('종목', sportLabels[w.sport] ?? w.sport)];
  if (w.distanceM != null) {
    rows.add(('거리', '${(w.distanceM! / 1000).toStringAsFixed(1)} km'));
  }
  if (w.steps != null) rows.add(('걸음 수', '${comma(w.steps!)}보'));
  if (w.bodyPart != null) rows.add(('부위', bodyPartLabels[w.bodyPart] ?? w.bodyPart!));
  if (w.sets != null) rows.add(('세트', '${w.sets}세트'));
  rows.add(('시간', '${w.minutes}분'));
  if (w.distanceM != null && w.durationSec > 0 && w.distanceM! > 0) {
    final paceSec = (w.durationSec / (w.distanceM! / 1000)).round();
    rows.add(('페이스', "${paceSec ~/ 60}'${(paceSec % 60).toString().padLeft(2, '0')}\""));
  }
  return rows;
}

/// 프로필/아바타 색: 닉네임 해시 → 오운 팔레트.
const List<Color> _avatarPalette = [
  Color(0xFFC47A45),
  Color(0xFFC9865B),
  Color(0xFF7FA98C),
  Color(0xFFB58BB0),
  Color(0xFFC99F5B),
  Color(0xFFA9BBD0),
];

Color avatarColor(String nickname) =>
    _avatarPalette[nickname.hashCode.abs() % _avatarPalette.length];

/// 아바타 이니셜(표시 이름 첫 글자).
String initialOf(String name) => name.isEmpty ? '?' : name.characters.first;
