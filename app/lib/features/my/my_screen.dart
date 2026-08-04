import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';
import '../quest/quest_screen.dart';
import 'achievements_screen.dart';
import 'notifications_screen.dart';

/// 마이룸·프로필·월말 리포트·설정. 프로필은 서버 값.
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final coin = ref.watch(walletProvider).maybeWhen(
          data: comma,
          orElse: () => '—',
        );
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;

    return PageScaffold(
      title: '마이',
      onRefresh: () => refreshTab(ref, OunTab.my),
      children: [
        // 프로필 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OunColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OunColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: profile == null
                        ? OunColors.card
                        : avatarColor(profile.nickname),
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: profile == null
                    ? const Icon(Icons.person,
                        size: 30, color: OunColors.textFaint)
                    : Text(initialOf(profile.displayName),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${profile?.nickname ?? '…'}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                        profile == null
                            ? ''
                            : 'Lv.${profile.level} · 연속 ${profile.streakCurrent}일',
                        style: const TextStyle(
                            fontSize: 12, color: OunColors.textMuted)),
                  ],
                ),
              ),
              CoinChip(amount: coin),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 메뉴
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: OunColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OunColors.cardBorder),
          ),
          child: Column(
            children: [
              _MenuItem(
                Icons.flag_outlined,
                '퀘스트',
                onTap: (context) =>
                    Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const QuestScreen()),
                ),
              ),
              _MenuItem(
                Icons.notifications_none_rounded,
                '알림 · 받은 응원',
                badge: unread,
                onTap: (context) =>
                    Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen()),
                ),
              ),
              _MenuItem(
                Icons.emoji_events_outlined,
                '업적',
                onTap: (context) =>
                    Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const AchievementsScreen()),
                ),
              ),
              const _MenuItem(Icons.cottage_outlined, '마이룸 꾸미기'),
              const _MenuItem(Icons.description_outlined, '월말 리포트'),
              _MenuItem(Icons.shield_outlined,
                  '기록 보호권 · ${profile?.streakProtectors ?? 0}개'),
              const _MenuItem(Icons.notifications_outlined, '알림 설정'),
              const _MenuItem(Icons.settings_outlined, '설정', last: true),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // 푸터: 버전 · 로그아웃
        Center(
          child: Column(
            children: [
              const Text('오운 v0.1.0',
                  style: TextStyle(fontSize: 11, color: OunColors.textFaint)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: const Text('로그아웃',
                    style: TextStyle(
                        fontSize: 12,
                        color: OunColors.textMuted,
                        decoration: TextDecoration.underline,
                        decorationColor: OunColors.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.icon, this.label,
      {this.last = false, this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final bool last;
  final void Function(BuildContext)? onTap;

  /// 0보다 크면 라벨 옆에 안 읽은 수 뱃지를 띄운다.
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap != null
            ? onTap!(context)
            : OunToast.show(context, '$label · 준비 중이에요'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: OunColors.cardBorder)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: OunColors.tabAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: OunColors.textPrimary)),
              ),
              if (badge > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: OunColors.tabAccent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              const Icon(Icons.chevron_right,
                  size: 18, color: OunColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
