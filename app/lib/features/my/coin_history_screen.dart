import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';

/// 코인 내역: 어디서 얼마를 받고 썼는지. 금액·잔액은 서버 원장 값 그대로.
class CoinHistoryScreen extends ConsumerWidget {
  const CoinHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coinHistoryProvider);
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('코인 내역',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OunColors.tabAccent)),
        error: (_, _) => const Center(
          child: Text('코인 내역을 불러오지 못했어요',
              style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
        data: (h) => RefreshIndicator(
          color: OunColors.tabAccent,
          onRefresh: () => ref.refresh(coinHistoryProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              _Summary(h),
              const SizedBox(height: 16),
              if (h.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text('아직 코인 내역이 없어요\n운동을 기록하면 코인이 쌓여요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: OunColors.textMuted)),
                )
              else
                for (final (day, rows) in _byDay(h.entries)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(day,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textMuted)),
                  ),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: OunColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OunColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          _Row(rows[i], last: i == rows.length - 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          ),
        ),
      ),
    );
  }

  /// 최신순 목록을 날짜별로 묶는다: 오늘 / 어제 / 10월 3일.
  static List<(String, List<CoinHistoryEntry>)> _byDay(
      List<CoinHistoryEntry> entries) {
    final groups = <(String, List<CoinHistoryEntry>)>[];
    for (final e in entries) {
      final label = _dayLabel(e.createdAt);
      if (groups.isEmpty || groups.last.$1 != label) {
        groups.add((label, [e]));
      } else {
        groups.last.$2.add(e);
      }
    }
    return groups;
  }

  static String _dayLabel(DateTime t) {
    final rel = relativeDay(t);
    if (rel == '오늘' || rel == '어제') return rel;
    final now = DateTime.now();
    return t.year == now.year
        ? '${t.month}월 ${t.day}일'
        : '${t.year}년 ${t.month}월 ${t.day}일';
  }
}

/// 현재 잔액 + 목록 안에서 모은/쓴 코인.
class _Summary extends StatelessWidget {
  const _Summary(this.h);
  final CoinHistory h;

  @override
  Widget build(BuildContext context) {
    var earned = 0, spent = 0;
    for (final e in h.entries) {
      if (e.delta > 0) {
        earned += e.delta;
      } else {
        spent -= e.delta;
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: OunColors.coin.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.paid_rounded,
                size: 23, color: OunColors.coin),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${comma(h.balance)} 코인',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: OunColors.textPrimary)),
                const Text('지금 가진 코인',
                    style: TextStyle(
                        fontSize: 11.5, color: OunColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('모은 코인 +${comma(earned)}',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: OunColors.tabAccent)),
              const SizedBox(height: 3),
              Text('쓴 코인 -${comma(spent)}',
                  style: const TextStyle(
                      fontSize: 11.5, color: OunColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.e, {required this.last});
  final CoinHistoryEntry e;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = _describe(e);
    final gain = e.delta > 0;
    final t = e.createdAt;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: OunColors.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: OunColors.card,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: OunColors.tabAccent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: OunColors.textPrimary)),
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: OunColors.textFaint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${gain ? '+' : '-'}${comma(e.delta.abs())}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: gain ? OunColors.tabAccent : OunColors.textMuted)),
              const SizedBox(height: 2),
              Text('잔액 ${comma(e.balanceAfter)}',
                  style: const TextStyle(
                      fontSize: 10.5, color: OunColors.textFaint)),
            ],
          ),
        ],
      ),
    );
  }

  /// 원장 사유 + 연관 정보 → 아이콘·문구.
  static (IconData, String) _describe(CoinHistoryEntry e) {
    final sport = e.sport == 'etc' && (e.customSportName ?? '').isNotEmpty
        ? e.customSportName!
        : sportLabels[e.sport];
    final sportIcon = sportIcons[e.sport] ?? Icons.directions_run;
    switch (e.reason) {
      case 'workout_reward':
        return (sportIcon, sport == null ? '운동 보상' : '$sport 운동 보상');
      case 'refund':
        if (e.refType == 'workout_log') {
          return sport == null
              ? (Icons.undo_rounded, '지운 운동 기록')
              : (Icons.undo_rounded, '$sport 기록 수정');
        }
        return (Icons.undo_rounded, '코인 회수');
      case 'quest_reward':
        if (e.refType == 'crew_reward') {
          final lv = e.level == null ? '' : ' Lv.${e.level}';
          return (
            Icons.groups_rounded,
            e.title == null ? '크루 레벨 보상' : '${e.title} 크루$lv 보상',
          );
        }
        return (
          Icons.flag_rounded,
          e.title == null ? '퀘스트 보상' : '퀘스트 · ${e.title}',
        );
      case 'achievement':
        return (Icons.emoji_events_rounded, '업적 보상');
      case 'shop_purchase':
        return (
          Icons.shopping_bag_rounded,
          e.title == null ? '상점 구매' : '${e.title} 구매',
        );
      case 'rest_day':
        return (Icons.nightlight_round, '휴식일 보상');
    }
    return (Icons.paid_rounded, '코인 변동');
  }
}
