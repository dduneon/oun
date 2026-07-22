/// 백엔드 응답 모델. 서버가 상태의 source of truth — 앱은 표현만 담당한다.
library;

/// GET /me
class Profile {
  const Profile({
    required this.nickname,
    required this.displayName,
    required this.gender,
    required this.level,
    required this.coin,
    required this.streakCurrent,
    required this.streakLongest,
    required this.streakProtectors,
  });

  final String nickname;
  final String displayName;
  final String gender; // 'f' | 'm'
  final int level;
  final int coin;
  final int streakCurrent;
  final int streakLongest;
  final int streakProtectors;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        nickname: j['nickname'] as String,
        displayName: j['displayName'] as String,
        gender: j['gender'] as String,
        level: j['level'] as int,
        coin: j['coin'] as int,
        streakCurrent: (j['streak'] as Map<String, dynamic>)['current'] as int,
        streakLongest: (j['streak'] as Map<String, dynamic>)['longest'] as int,
        streakProtectors: j['streakProtectors'] as int,
      );
}

/// 운동 기록 요약(서버 workoutSummary 셰이프).
class Workout {
  const Workout({
    required this.id,
    required this.sport,
    required this.durationSec,
    required this.performedAt,
    this.distanceM,
    this.steps,
    this.bodyPart,
    this.sets,
    this.hasPhoto = false,
  });

  final String id;
  final String sport;
  final int durationSec;
  final DateTime performedAt;
  final int? distanceM;
  final int? steps;
  final String? bodyPart;
  final int? sets;
  final bool hasPhoto;

  int get minutes => durationSec ~/ 60;

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'] as String,
        sport: j['sport'] as String,
        durationSec: j['durationSec'] as int,
        performedAt: DateTime.parse(j['performedAt'] as String).toLocal(),
        distanceM: j['distanceM'] as int?,
        steps: j['steps'] as int?,
        bodyPart: j['bodyPart'] as String?,
        sets: j['sets'] as int?,
        hasPhoto: (j['hasPhoto'] as bool?) ?? (j['photoRef'] != null),
      );
}

/// GET /workouts/calendar 한 칸.
class CalendarDay {
  const CalendarDay({required this.date, required this.minutes, required this.intensity});
  final String date; // YYYY-MM-DD
  final int minutes;
  final int intensity; // 0~4

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        date: j['date'] as String,
        minutes: j['minutes'] as int,
        intensity: j['intensity'] as int,
      );
}

/// GET /workouts/summary
class MonthSummary {
  const MonthSummary({
    required this.workoutDays,
    required this.totalMinutes,
    required this.longestStreak,
  });
  final int workoutDays;
  final int totalMinutes;
  final int longestStreak;

  factory MonthSummary.fromJson(Map<String, dynamic> j) => MonthSummary(
        workoutDays: j['workoutDays'] as int,
        totalMinutes: j['totalMinutes'] as int,
        longestStreak: j['longestStreak'] as int,
      );
}

/// GET /quests 한 개.
class Quest {
  const Quest({
    required this.key,
    required this.kind,
    required this.title,
    required this.sub,
    required this.reward,
    required this.goal,
    required this.progress,
    required this.state,
    this.icon,
  });

  final String key;
  final String kind;
  final String title;
  final String sub;
  final int reward;
  final int goal;
  final int progress;
  final String state; // in_progress | claimable | claimed
  final String? icon;

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
        key: j['key'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        sub: j['sub'] as String,
        reward: j['reward'] as int,
        goal: j['goal'] as int,
        progress: j['progress'] as int,
        state: j['state'] as String,
        icon: j['icon'] as String?,
      );
}

/// GET /quests 응답(일일/주간/도전).
class QuestBoard {
  const QuestBoard({required this.daily, required this.weekly, required this.challenge});
  final List<Quest> daily;
  final List<Quest> weekly;
  final List<Quest> challenge;

  bool get hasClaimable => [...daily, ...weekly, ...challenge].any((q) => q.state == 'claimable');

  factory QuestBoard.fromJson(Map<String, dynamic> j) => QuestBoard(
        daily: (j['daily'] as List).map((e) => Quest.fromJson(e as Map<String, dynamic>)).toList(),
        weekly: (j['weekly'] as List).map((e) => Quest.fromJson(e as Map<String, dynamic>)).toList(),
        challenge: (j['challenge'] as List)
            .map((e) => Quest.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// GET /shop/items 한 개.
class ShopItem {
  const ShopItem({
    required this.key,
    required this.category,
    required this.name,
    required this.price,
    required this.owned,
    this.colorHex,
  });

  final String key;
  final String category;
  final String name;
  final int price;
  final bool owned;
  final String? colorHex;

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
        key: j['key'] as String,
        category: j['category'] as String,
        name: j['name'] as String,
        price: j['price'] as int,
        owned: j['owned'] as bool,
        colorHex: j['colorHex'] as String?,
      );
}

/// GET /achievements 한 개.
class Achievement {
  const Achievement({
    required this.key,
    required this.name,
    required this.condition,
    required this.earned,
    this.icon,
  });

  final String key;
  final String name;
  final String condition;
  final bool earned;
  final String? icon;

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        key: j['key'] as String,
        name: j['name'] as String,
        condition: j['condition'] as String,
        earned: j['earned'] as bool,
        icon: j['icon'] as String?,
      );
}

/// GET /friends 한 명.
class Friend {
  const Friend({
    required this.nickname,
    required this.displayName,
    required this.gender,
    required this.streakCurrent,
    required this.workedOutToday,
    required this.reactions,
    this.latestWorkout,
  });

  final String nickname;
  final String displayName;
  final String gender;
  final int streakCurrent;
  final bool workedOutToday;
  final List<String> reactions;
  final Workout? latestWorkout;

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        nickname: j['nickname'] as String,
        displayName: j['displayName'] as String,
        gender: j['gender'] as String,
        streakCurrent: j['streakCurrent'] as int,
        workedOutToday: j['workedOutToday'] as bool,
        reactions: (j['reactions'] as List).cast<String>(),
        latestWorkout: j['latestWorkout'] == null
            ? null
            : Workout.fromJson(j['latestWorkout'] as Map<String, dynamic>),
      );
}

/// GET /users/:nickname/home
class FriendHome {
  const FriendHome({
    required this.nickname,
    required this.displayName,
    required this.gender,
    required this.level,
    required this.streakCurrent,
    required this.weekDone,
    required this.weekCount,
    required this.weekMinutes,
    required this.recent,
  });

  final String nickname;
  final String displayName;
  final String gender;
  final int level;
  final int streakCurrent;
  final List<bool> weekDone; // 월~일
  final int weekCount;
  final int weekMinutes;
  final List<Workout> recent;

  factory FriendHome.fromJson(Map<String, dynamic> j) => FriendHome(
        nickname: j['nickname'] as String,
        displayName: j['displayName'] as String,
        gender: j['gender'] as String,
        level: j['level'] as int,
        streakCurrent: j['streakCurrent'] as int,
        weekDone: (j['weekDone'] as List).cast<bool>(),
        weekCount: j['weekCount'] as int,
        weekMinutes: j['weekMinutes'] as int,
        recent:
            (j['recent'] as List).map((e) => Workout.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// 크루 레벨 정보(서버 crewLevelOf 셰이프).
class CrewLevel {
  const CrewLevel({
    required this.level,
    required this.intoLevel,
    required this.levelSpan,
    required this.total,
  });

  final int level;
  final int intoLevel;
  final int levelSpan;
  final int total;

  double get ratio => levelSpan == 0 ? 1 : (intoLevel / levelSpan).clamp(0.0, 1.0);
  int get toNext => (levelSpan - intoLevel).clamp(0, levelSpan);

  factory CrewLevel.fromJson(Map<String, dynamic> j) => CrewLevel(
        level: j['level'] as int,
        intoLevel: j['intoLevel'] as int,
        levelSpan: j['levelSpan'] as int,
        total: j['total'] as int,
      );
}

/// GET /crews 카드 한 장(내가 속한 크루).
class CrewCardData {
  const CrewCardData({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.memberCount,
    required this.level,
  });

  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final int memberCount;
  final CrewLevel level;

  factory CrewCardData.fromJson(Map<String, dynamic> j) => CrewCardData(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        isPublic: j['isPublic'] as bool? ?? true,
        memberCount: j['memberCount'] as int,
        level: CrewLevel.fromJson(j['level'] as Map<String, dynamic>),
      );
}

/// 크루 상세의 멤버 한 명.
class CrewMemberData {
  const CrewMemberData({
    required this.nickname,
    required this.displayName,
    required this.gender,
    required this.role,
    required this.isMe,
  });

  final String nickname;
  final String displayName;
  final String gender;
  final String role; // leader | member
  final bool isMe;

  bool get isLeader => role == 'leader';

  /// Unity 크루 씬 캐릭터 토큰.
  String get charToken => gender == 'm' ? 'm' : 'f';

  factory CrewMemberData.fromJson(Map<String, dynamic> j) => CrewMemberData(
        nickname: j['nickname'] as String,
        displayName: j['displayName'] as String,
        gender: j['gender'] as String,
        role: j['role'] as String,
        isMe: j['isMe'] as bool,
      );
}

/// GET /crews/:id
class CrewDetail {
  const CrewDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.isLeader,
    required this.pendingRequestCount,
    required this.members,
    required this.level,
  });

  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final bool isLeader; // 내가 방장인지(설정·초대·신청 관리 권한)
  final int pendingRequestCount; // 방장에게 온 대기중 가입 신청 수
  final List<CrewMemberData> members;
  final CrewLevel level;

  factory CrewDetail.fromJson(Map<String, dynamic> j) => CrewDetail(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        isPublic: j['isPublic'] as bool? ?? true,
        isLeader: j['isLeader'] as bool? ?? false,
        pendingRequestCount: j['pendingRequestCount'] as int? ?? 0,
        members: (j['members'] as List)
            .map((e) => CrewMemberData.fromJson(e as Map<String, dynamic>))
            .toList(),
        level: CrewLevel.fromJson(j['level'] as Map<String, dynamic>),
      );
}

/// GET /crews/discover 의 공개 크루 한 장.
class CrewSummary {
  const CrewSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.level,
    required this.requested,
  });

  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final CrewLevel level;
  final bool requested; // 내가 이미 가입 신청했는지

  factory CrewSummary.fromJson(Map<String, dynamic> j) => CrewSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        memberCount: j['memberCount'] as int,
        level: CrewLevel.fromJson(j['level'] as Map<String, dynamic>),
        requested: j['requested'] as bool? ?? false,
      );
}

/// GET /crews/invitations 의 받은 초대 한 건.
class CrewInvitation {
  const CrewInvitation({
    required this.id,
    required this.crewId,
    required this.crewName,
    required this.crewDescription,
    required this.memberCount,
    required this.invitedByName,
  });

  final String id;
  final String crewId;
  final String crewName;
  final String? crewDescription;
  final int memberCount;
  final String? invitedByName;

  factory CrewInvitation.fromJson(Map<String, dynamic> j) => CrewInvitation(
        id: j['id'] as String,
        crewId: j['crewId'] as String,
        crewName: j['crewName'] as String,
        crewDescription: j['crewDescription'] as String?,
        memberCount: j['memberCount'] as int,
        invitedByName: j['invitedByName'] as String?,
      );
}

/// GET /crews/:id/join-requests 의 대기중 가입 신청 한 건(방장 화면).
class CrewJoinRequestItem {
  const CrewJoinRequestItem({
    required this.id,
    required this.nickname,
    required this.displayName,
    required this.gender,
  });

  final String id;
  final String nickname;
  final String displayName;
  final String gender;

  factory CrewJoinRequestItem.fromJson(Map<String, dynamic> j) =>
      CrewJoinRequestItem(
        id: j['id'] as String,
        nickname: j['nickname'] as String,
        displayName: j['displayName'] as String,
        gender: j['gender'] as String,
      );
}

/// 피드 글쓴이/댓글쓴이.
class PostAuthor {
  const PostAuthor({required this.nickname, required this.displayName, required this.isMe, this.gender});
  final String nickname;
  final String displayName;
  final bool isMe;
  final String? gender;

  factory PostAuthor.fromJson(Map<String, dynamic> j) => PostAuthor(
        nickname: j['nickname'] as String,
        displayName: j['displayName'] as String,
        isMe: (j['isMe'] as bool?) ?? false,
        gender: j['gender'] as String?,
      );
}

/// 피드 댓글.
class CrewCommentData {
  const CrewCommentData({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final PostAuthor author;
  final String text;
  final DateTime createdAt;

  factory CrewCommentData.fromJson(Map<String, dynamic> j) => CrewCommentData(
        id: j['id'] as String,
        author: PostAuthor.fromJson(j['author'] as Map<String, dynamic>),
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );
}

/// GET /crews/:id/feed 글 하나.
class CrewPostData {
  CrewPostData({
    required this.id,
    required this.author,
    required this.createdAt,
    required this.cheers,
    required this.cheered,
    required this.comments,
    this.message,
    this.workout,
  });

  final String id;
  final PostAuthor author;
  final DateTime createdAt;
  final String? message;
  final Workout? workout;
  int cheers;
  bool cheered;
  final List<CrewCommentData> comments;

  factory CrewPostData.fromJson(Map<String, dynamic> j) => CrewPostData(
        id: j['id'] as String,
        author: PostAuthor.fromJson(j['author'] as Map<String, dynamic>),
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        message: j['message'] as String?,
        workout: j['workout'] == null
            ? null
            : Workout.fromJson(j['workout'] as Map<String, dynamic>),
        cheers: j['cheers'] as int,
        cheered: j['cheered'] as bool,
        comments: (j['comments'] as List)
            .map((e) => CrewCommentData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// GET /crews/:id/rewards 한 줄.
class CrewReward {
  const CrewReward({
    required this.level,
    required this.label,
    required this.coins,
    required this.unlocked,
    required this.claimed,
  });

  final int level;
  final String label;
  final int coins;
  final bool unlocked;
  final bool claimed;

  factory CrewReward.fromJson(Map<String, dynamic> j) => CrewReward(
        level: j['level'] as int,
        label: j['label'] as String,
        coins: j['coins'] as int,
        unlocked: j['unlocked'] as bool,
        claimed: j['claimed'] as bool,
      );
}

/// POST /workouts 응답 요약.
class WorkoutResult {
  const WorkoutResult({required this.verified, required this.reward, required this.balance});
  final bool verified;
  final int reward;
  final int balance;
}

/// POST /quests/:key/claim 응답.
class ClaimResult {
  const ClaimResult({required this.reward, required this.balance});
  final int reward;
  final int balance;
}
