import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/login_screen.dart';
import 'router.dart';
import 'shared/api/providers.dart';
import 'shared/global_keys.dart';
import 'shared/push/push_messaging.dart';
import 'theme/app_theme.dart';

class OunApp extends ConsumerStatefulWidget {
  const OunApp({super.key});

  @override
  ConsumerState<OunApp> createState() => _OunAppState();
}

class _OunAppState extends ConsumerState<OunApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 백그라운드에 있는 동안 온 푸시는 포그라운드 핸들러를 타지 않는다.
    // (배너를 탭하지 않고 앱으로 돌아오면 아무것도 갱신되지 않아, 알림만 오고
    //  화면엔 안 나오는 상태가 된다) 복귀할 때 알림함·소셜 목록을 다시 읽는다.
    _lifecycle = AppLifecycleListener(onResume: _refreshOnResume);
  }

  void _refreshOnResume() {
    if (ref.read(authProvider).status != AuthStatus.loggedIn) return;
    invalidateAll(ref, [...inboxProviders, ...socialProviders]);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // 로그인/로그아웃에 맞춰 푸시 토큰을 등록·해제한다.
    // (Firebase 미설정이면 start()가 조용히 no-op)
    ref.listen(authProvider, (prev, next) {
      if (prev?.status == next.status) return;
      final push = ref.read(pushMessagingProvider);
      if (next.status == AuthStatus.loggedIn) {
        push.start();
      } else if (next.status == AuthStatus.loggedOut) {
        push.stop();
      }
    });

    return MaterialApp.router(
      title: '오운',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: router,
      // 로그인 전에는 라우터 위를 로그인/스플래시가 덮는다(인증 게이트).
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(child: child ?? const SizedBox.shrink()),
            if (auth.status == AuthStatus.loggedOut)
              const Positioned.fill(child: LoginScreen())
            else if (auth.needsOnboarding)
              const Positioned.fill(child: OnboardingScreen())
            else
              Positioned.fill(
                child: _Splash(
                  visible: auth.status == AuthStatus.restoring,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 세션 복원 동안의 스플래시.
/// 걷힐 때만 부드럽게 사라진다(나타날 때는 즉시).
class _Splash extends StatelessWidget {
  const _Splash({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: visible ? Duration.zero : const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: const ColoredBox(
          color: OunColors.background,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets_rounded, size: 44, color: OunColors.tabAccent),
                SizedBox(height: 14),
                Text('오운',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: OunColors.textPrimary)),
                SizedBox(height: 20),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: OunColors.tabAccent),
                ),
                SizedBox(height: 12),
                Text('오운이를 깨우는 중…',
                    style:
                        TextStyle(fontSize: 12.5, color: OunColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
