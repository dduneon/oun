import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';

/// 알림함 + 받은 응원.
///
/// 응원은 "보내는 쪽"만 있던 기능이라 받은 사람이 확인할 곳이 없었다.
/// 이 화면이 그 수신자 측 창구다. 알림 탭은 열면 읽음 처리되고,
/// 응원 탭은 홈 캐릭터 반응이 이미 확인 처리하므로 목록만 보여준다.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0; // 0: 알림, 1: 받은 응원

  @override
  void initState() {
    super.initState();
    // 화면을 연 것 자체가 확인 — 첫 프레임 뒤에 전체 읽음 처리.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(apiClientProvider).markNotificationsRead();
      ref.invalidate(unreadNotificationsProvider);
      ref.invalidate(notificationsProvider);
    } catch (_) {
      // 읽음 처리 실패는 조용히 무시 — 다음 진입에 다시 시도된다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('알림',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: _Segments(
              index: _tab,
              labels: const ['알림', '받은 응원'],
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: _tab == 0 ? const _NotificationList() : const _CheerList(),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index ? OunColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                      color: i == index
                          ? OunColors.textPrimary
                          : OunColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: OunColors.textFaint),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, color: OunColors.textMuted)),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: OunColors.tabAccent));
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(notificationsProvider).when(
          loading: () => const _Loading(),
          error: (_, _) => const _Empty(
              Icons.notifications_off_outlined, '알림을 불러오지 못했어요'),
          data: (board) {
            if (board.items.isEmpty) {
              return const _Empty(
                  Icons.notifications_none_rounded, '아직 알림이 없어요');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              itemCount: board.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NotificationTile(board.items[i]),
            );
          },
        );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(this.n);
  final NotificationItem n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: OunColors.tabAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              n.type == 'cheer'
                  ? Icons.favorite_rounded
                  : Icons.notifications_rounded,
              size: 20,
              color: OunColors.tabAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: OunColors.textPrimary)),
                    ),
                    Text(relativeTime(n.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: OunColors.textFaint)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(n.body,
                    style: const TextStyle(
                        fontSize: 12.5, color: OunColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheerList extends ConsumerWidget {
  const _CheerList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(receivedCheersProvider).when(
          loading: () => const _Loading(),
          error: (_, _) =>
              const _Empty(Icons.favorite_border_rounded, '응원을 불러오지 못했어요'),
          data: (cheers) {
            if (cheers.items.isEmpty) {
              return const _Empty(
                  Icons.favorite_border_rounded, '아직 받은 응원이 없어요');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              itemCount: cheers.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _CheerTile(cheers.items[i]),
            );
          },
        );
  }
}

class _CheerTile extends StatelessWidget {
  const _CheerTile(this.c);
  final ReceivedCheer c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: avatarColor(c.fromNickname), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initialOf(c.fromDisplayName),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.fromDisplayName}님의 응원',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: OunColors.textPrimary)),
                const SizedBox(height: 3),
                Text('@${c.fromNickname} · ${relativeTime(c.createdAt)}',
                    style: const TextStyle(
                        fontSize: 11.5, color: OunColors.textFaint)),
              ],
            ),
          ),
          Text(c.emoji, style: const TextStyle(fontSize: 22)),
        ],
      ),
    );
  }
}
