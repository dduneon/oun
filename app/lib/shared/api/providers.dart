import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 앱 전역 API 클라이언트.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// 코인 잔액. 세션이 없으면 dev 로그인 후 GET /wallet.
///
/// MVP 확인용 단일 흐름 — 서버가 켜져 있으면 실제 잔액이, 꺼져 있으면
/// 에러가 나므로 UI는 로딩/실패를 관대하게 처리한다.
final walletProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(apiClientProvider);
  await api.ensureSession();
  return api.wallet();
});
