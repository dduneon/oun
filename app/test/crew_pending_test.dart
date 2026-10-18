import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oun_app/features/crew/crew_screen.dart';
import 'package:oun_app/shared/api/models.dart';
import 'package:oun_app/shared/api/providers.dart';

CrewCardData crew(String id, String name) => CrewCardData.fromJson({
      'id': id,
      'name': name,
      'description': null,
      'isPublic': true,
      'memberCount': 3,
      'level': {'level': 2, 'intoLevel': 1, 'levelSpan': 10, 'total': 11},
    });

class _CrewTab extends SocialSegmentController {
  @override
  int build() => 1;
}

void main() {
  testWidgets('가입 신청한 크루는 크루 목록에 신청 대기중으로 보인다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialSegmentProvider.overrideWith(_CrewTab.new),
          crewsProvider.overrideWith((ref) async => [crew('c1', '아침 산책단')]),
          myCrewJoinRequestsProvider
              .overrideWith((ref) async => [crew('c2', '저녁 러닝 크루')]),
          crewInvitationsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: CrewScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('아침 산책단'), findsOneWidget);
    expect(find.text('가입 신청한 크루'), findsOneWidget);
    expect(find.text('저녁 러닝 크루'), findsOneWidget);
    expect(find.text('신청 대기중'), findsOneWidget);
  });

  testWidgets('소속 크루가 없어도 신청 대기중인 크루는 보인다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialSegmentProvider.overrideWith(_CrewTab.new),
          crewsProvider.overrideWith((ref) async => []),
          myCrewJoinRequestsProvider
              .overrideWith((ref) async => [crew('c2', '저녁 러닝 크루')]),
          crewInvitationsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: CrewScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('신청 대기중'), findsOneWidget);
    expect(find.text('아직 소속된 크루가 없어요'), findsOneWidget);
  });
}
