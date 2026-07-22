import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 크루 탐방: 공개 크루를 둘러보고 가입 신청한다.
class CrewDiscoverScreen extends ConsumerStatefulWidget {
  const CrewDiscoverScreen({super.key});

  @override
  ConsumerState<CrewDiscoverScreen> createState() => _CrewDiscoverScreenState();
}

class _CrewDiscoverScreenState extends ConsumerState<CrewDiscoverScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _request(CrewSummary crew) async {
    try {
      await ref.read(apiClientProvider).requestJoinCrew(crew.id);
      ref.invalidate(crewDiscoverProvider(_query));
      if (mounted) {
        OunToast.show(context, '${crew.name} 크루에 가입 신청했어요',
            kind: OunToastKind.success);
      }
    } catch (_) {
      if (mounted) OunToast.show(context, '가입 신청에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(crewDiscoverProvider(_query));
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('크루 찾기',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OunColors.textPrimary)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: OunColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _query = v.trim()),
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 14, color: OunColors.textPrimary),
              decoration: InputDecoration(
                hintText: '크루 이름으로 검색',
                hintStyle: const TextStyle(color: OunColors.textFaint),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: OunColors.textMuted),
                filled: true,
                fillColor: OunColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: OunColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: OunColors.tabAccent),
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: OunColors.tabAccent)),
              error: (_, _) => const Center(
                child: Text('크루를 불러오지 못했어요',
                    style: TextStyle(fontSize: 12.5, color: OunColors.textFaint)),
              ),
              data: (crews) {
                if (crews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.travel_explore_rounded,
                            size: 46, color: OunColors.textFaint),
                        const SizedBox(height: 12),
                        Text(
                            _query.isEmpty
                                ? '아직 공개된 크루가 없어요'
                                : "'$_query' 크루를 찾지 못했어요",
                            style: const TextStyle(
                                fontSize: 13, color: OunColors.textMuted)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: crews.length,
                  itemBuilder: (_, i) =>
                      _DiscoverCard(crew: crews[i], onRequest: () => _request(crews[i])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.crew, required this.onRequest});
  final CrewSummary crew;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final hasDesc = crew.description != null && crew.description!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: OunColors.card,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups,
                    size: 24, color: OunColors.tabAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crew.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('멤버 ${crew.memberCount}명 · Lv.${crew.level.level}',
                        style: const TextStyle(
                            fontSize: 11.5, color: OunColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (hasDesc) ...[
            const SizedBox(height: 10),
            Text(crew.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.35, color: OunColors.textMuted)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: crew.requested
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OunColors.textMuted,
                      side: const BorderSide(color: OunColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('신청됨',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: OunColors.tabAccent,
                      foregroundColor: OunColors.onTabAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onRequest,
                    child: const Text('가입 신청',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
    );
  }
}
