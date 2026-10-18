import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 쉬어 가기(Care System): 휴식일 선언 + 기록 보호권.
/// 쉬는 날을 처벌하지 않는다 — 휴식일·보호권 모두 연속 기록을 이어 준다.
/// 지급·사용 판정은 서버가 하고, 앱은 보여 주기만 한다.
class CareScreen extends ConsumerWidget {
  const CareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(careProvider);
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text(
          '쉬어 가기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: OunColors.textPrimary,
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: OunColors.tabAccent),
        ),
        error: (_, _) => const Center(
          child: Text(
            '불러오지 못했어요',
            style: TextStyle(fontSize: 13, color: OunColors.textMuted),
          ),
        ),
        data: (care) => RefreshIndicator(
          color: OunColors.tabAccent,
          onRefresh: () => ref.refresh(careProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              _RestDayCard(care: care),
              const SizedBox(height: 12),
              _ProtectorCard(care: care),
              const SizedBox(height: 16),
              const Text(
                '휴식일과 보호권이 메운 날은 연속 기록을 끊지 않고 이어 줘요.\n'
                '쉬는 날도 꾸준함의 일부예요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: OunColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: OunColors.tabAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: OunColors.tabAccent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: OunColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RestDayCard extends ConsumerWidget {
  const _RestDayCard({required this.care});
  final CareStatus care;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      icon: Icons.bedtime_outlined,
      title: '휴식일',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘을 공식 휴식일로 정하면 연속 기록이 이어지고 '
            '${care.restReward} 코인을 받아요. 한 주에 ${care.restWeeklyLimit}번까지.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: OunColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _Dots(used: care.restUsedThisWeek, total: care.restWeeklyLimit),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OunColors.tabAccent,
                foregroundColor: OunColors.onTabAccent,
                disabledBackgroundColor: OunColors.card,
                disabledForegroundColor: OunColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: care.canDeclareRest
                  ? () => confirmRestDay(context, ref, care)
                  : null,
              child: Text(
                care.restToday
                    ? '오늘은 쉬는 날이에요'
                    : care.canDeclareRest
                    ? '오늘은 쉬어 갈래요'
                    : care.restBlockedReason ?? '오늘은 선언할 수 없어요',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectorCard extends StatelessWidget {
  const _ProtectorCard({required this.care});
  final CareStatus care;

  @override
  Widget build(BuildContext context) {
    final next = care.nextProtectorInDays;
    return _Card(
      icon: Icons.shield_outlined,
      title: '기록 보호권',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < care.protectorMax; i++) ...[
                Icon(
                  i < care.protectors
                      ? Icons.shield_rounded
                      : Icons.shield_outlined,
                  size: 30,
                  color: i < care.protectors
                      ? OunColors.tabAccent
                      : OunColors.cardBorder,
                ),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 4),
              Text(
                '${care.protectors} / ${care.protectorMax}개',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: OunColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '운동을 빠뜨린 날이 있으면 보호권이 알아서 그날을 메워요. '
            '연속 ${care.protectorEvery}일마다 1개씩 받고, '
            '${care.protectorMax}개까지 모아 둘 수 있어요.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: OunColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            next == null ? '보호권을 가득 모았어요' : '다음 보호권까지 연속 $next일 남았어요',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: OunColors.tabAccent,
            ),
          ),
          if (care.recentProtectedDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '보호권이 지켜 준 날',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: OunColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in care.recentProtectedDates)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: OunColors.card,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _monthDay(d),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: OunColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 'YYYY-MM-DD' → 'M월 D일'
  static String _monthDay(String ymd) {
    final p = ymd.split('-');
    return '${int.parse(p[1])}월 ${int.parse(p[2])}일';
  }
}

/// 이번 주 휴식일 사용 현황(●●).
class _Dots extends StatelessWidget {
  const _Dots({required this.used, required this.total});
  final int used;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '이번 주',
          style: TextStyle(fontSize: 12, color: OunColors.textMuted),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < total; i++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < used ? OunColors.tabAccent : OunColors.cardBorder,
            ),
          ),
        const SizedBox(width: 3),
        Text(
          '$used/$total',
          style: const TextStyle(fontSize: 12, color: OunColors.textMuted),
        ),
      ],
    );
  }
}

/// 휴식일 선언 확인 시트 → 서버 선언 → 관련 데이터 갱신 + 토스트.
/// 홈 카드와 쉬어 가기 화면에서 같이 쓴다.
Future<void> confirmRestDay(
  BuildContext context,
  WidgetRef ref,
  CareStatus care,
) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      decoration: const BoxDecoration(
        color: OunColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: OunColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.bedtime_rounded,
              size: 34,
              color: OunColors.tabAccent,
            ),
            const SizedBox(height: 10),
            const Text(
              '오늘은 쉬어 갈까요?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OunColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '연속 기록은 그대로 이어지고 ${care.restReward} 코인을 받아요.\n'
              '이번 주 ${care.restUsedThisWeek + 1}/${care.restWeeklyLimit}번째 휴식일이에요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: OunColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OunColors.tabAccent,
                  foregroundColor: OunColors.onTabAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: const Text(
                  '쉬어 갈래요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(false),
              child: const Text(
                '조금 더 생각해 볼게요',
                style: TextStyle(fontSize: 13, color: OunColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final reward = await ref.read(apiClientProvider).declareRestDay();
    invalidateAll(ref, careProviders);
    OunToast.showWith(
      messenger,
      '오늘은 푹 쉬어요 · +$reward 코인',
      kind: OunToastKind.success,
    );
  } catch (e) {
    invalidateAll(ref, careProviders);
    OunToast.showWith(messenger, apiErrorMessage(e, '휴식일을 정하지 못했어요'));
  }
}
