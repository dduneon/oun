import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 로그인/회원가입. 닉네임 + 캐릭터 선택으로 시작한다.
/// 지금은 dev 인증(닉네임만) — 카카오 로그인은 버튼만 자리해 두고 곧 연결.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nickname = TextEditingController();
  String _gender = 'f';
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok =
        await ref.read(authProvider.notifier).login(nickname, gender: _gender);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      OunToast.show(context, ref.read(authProvider).error ?? '로그인에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _nickname.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      backgroundColor: OunColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // 로고/타이틀
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.pets_rounded, size: 52, color: OunColors.tabAccent),
                    SizedBox(height: 14),
                    Text('오운',
                        style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: OunColors.textPrimary,
                            letterSpacing: -0.5)),
                    SizedBox(height: 6),
                    Text('오늘의 운동, 나만의 속도로 귀엽게 차곡차곡',
                        style:
                            TextStyle(fontSize: 13, color: OunColors.textMuted)),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              const Text('닉네임',
                  style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: _nickname,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _start(),
                maxLength: 20,
                textInputAction: TextInputAction.done,
                style:
                    const TextStyle(fontSize: 15, color: OunColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '예: oun_dduneon',
                  hintStyle: const TextStyle(color: OunColors.textFaint),
                  counterText: '',
                  filled: true,
                  fillColor: OunColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
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
              const SizedBox(height: 16),
              const Text('함께할 캐릭터',
                  style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _genderCard('f', '여자 아이', Icons.face_3)),
                  const SizedBox(width: 10),
                  Expanded(child: _genderCard('m', '남자 아이', Icons.face_6)),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OunColors.tabAccent,
                  foregroundColor: OunColors.onTabAccent,
                  disabledBackgroundColor: OunColors.cardBorder,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: canStart ? _start : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: OunColors.onTabAccent))
                    : const Text('시작하기',
                        style: TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              // 카카오 로그인 자리(백엔드 POST /auth/kakao 준비됨, 앱 SDK 연동 예정)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: OunColors.textPrimary,
                  side: const BorderSide(color: OunColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () =>
                    OunToast.show(context, '카카오 로그인은 곧 열려요'),
                icon: const Icon(Icons.chat_bubble, size: 17),
                label: const Text('카카오로 시작하기',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _genderCard(String value, String label, IconData icon) {
    final selected = _gender == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? OunColors.tabAccent : OunColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? OunColors.tabAccent : OunColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 26,
                color: selected ? OunColors.onTabAccent : OunColors.tabAccent),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? OunColors.onTabAccent
                        : OunColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
