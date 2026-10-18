import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 알림 설정: 분류별 푸시 끄기. 꺼도 알림함에는 그대로 남는다(서버가 푸시만 거른다).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  /// 스위치를 누르자마자 반영해 보여 줄 값(서버 응답 전까지).
  NotificationSettings? _pending;

  static const _rows = [
    ('friends', Icons.person_add_alt_1_outlined, '친구', '친구 요청·수락'),
    ('cheers', Icons.favorite_border_rounded, '응원', '친구가 보낸 응원'),
    ('crew', Icons.groups_outlined, '크루', '초대·가입 신청·댓글·글 응원'),
    ('care', Icons.shield_outlined, '쉬어 가기', '기록 보호권이 연속 기록을 지켰을 때'),
  ];

  Future<void> _save(NotificationSettings current, Map<String, bool> patch) async {
    final next = NotificationSettings.fromJson({...current.toJson(), ...patch});
    setState(() => _pending = next);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).updateNotificationSettings(patch);
      ref.invalidate(notificationSettingsProvider);
      await ref.read(notificationSettingsProvider.future);
    } catch (e) {
      OunToast.showWith(messenger, apiErrorMessage(e, '설정을 바꾸지 못했어요'));
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationSettingsProvider);
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('알림 설정',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OunColors.tabAccent)),
        error: (_, _) => const Center(
          child: Text('불러오지 못했어요',
              style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
        data: (saved) {
          final s = _pending ?? saved;
          final values = s.toJson();
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              _Group(children: [
                _SwitchRow(
                  icon: Icons.notifications_active_outlined,
                  title: '푸시 알림 받기',
                  value: !s.allOff,
                  onChanged: (on) => _save(s, {
                    for (final (key, _, _, _) in _rows) key: on,
                  }),
                ),
              ]),
              const SizedBox(height: 12),
              _Group(children: [
                for (final (i, (key, icon, title, sub)) in _rows.indexed)
                  _SwitchRow(
                    icon: icon,
                    title: title,
                    subtitle: sub,
                    value: values[key]!,
                    last: i == _rows.length - 1,
                    onChanged: (on) => _save(s, {key: on}),
                  ),
              ]),
              const SizedBox(height: 14),
              const Text(
                '알림을 꺼도 알림함에는 그대로 남아요.\n'
                '기기에서 오운 알림을 막아 두었다면 iPhone 설정 > 알림에서 켜 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5, height: 1.5, color: OunColors.textFaint),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.last = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool last;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 10, 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: OunColors.cardBorder)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: OunColors.tabAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OunColors.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11.5, color: OunColors.textMuted)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: OunColors.tabAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
