import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/features/crew/crew_invite_sheet.dart';
import 'package:oun_app/shared/api/api_client.dart';
import 'package:oun_app/shared/api/models.dart';
import 'package:oun_app/shared/api/providers.dart';

class InviteApi extends ApiClient {
  final invited = <String>[];
  @override
  Future<String> inviteToCrew(String crewId, String nickname) async {
    invited.add(nickname);
    return nickname;
  }
}

Friend friend(String nickname, String name) => Friend(
  nickname: nickname,
  displayName: name,
  gender: 'f',
  streakCurrent: 0,
  workedOutToday: false,
  cheersLeftToday: 0,
);

void main() {
  testWidgets('친구 목록에서 골라 초대하고 이미 크루원인 친구는 고를 수 없다', (tester) async {
    final api = InviteApi();
    var byNickname = false;
    const crew = CrewDetail(
      id: 'c1',
      name: '달리는 크루',
      description: null,
      isPublic: true,
      isLeader: true,
      pendingRequestCount: 0,
      members: [
        CrewMemberData(
          nickname: 'me',
          displayName: '나',
          gender: 'f',
          role: 'leader',
          isMe: true,
        ),
        CrewMemberData(
          nickname: 'jimin',
          displayName: '지민',
          gender: 'f',
          role: 'member',
          isMe: false,
        ),
      ],
      level: CrewLevel(level: 1, intoLevel: 0, levelSpan: 10, total: 0),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          friendsProvider.overrideWith(
            (ref) async => [friend('jimin', '지민'), friend('seoyeon', '서연')],
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCrewInviteSheet(
                context,
                crew: crew,
                onInviteByNickname: () => byNickname = true,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('크루원'), findsOneWidget); // 지민은 이미 크루원
    expect(find.text('초대'), findsOneWidget); // 서연만 초대 가능
    await tester.tap(find.text('초대'));
    await tester.pumpAndSettle();
    expect(api.invited, ['seoyeon']);
    expect(find.text('보냈어요'), findsOneWidget);

    await tester.tap(find.text('친구가 아닌 사람은 닉네임으로 초대하기'));
    await tester.pumpAndSettle();
    expect(byNickname, isTrue);
  });
}
