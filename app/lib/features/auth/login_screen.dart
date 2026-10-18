import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/providers.dart';
import '../../shared/auth/social_sign_in.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 인증(로그인/회원가입) 오버레이. 자체 Navigator로 랜딩 → 회원가입/로그인을
/// 오가며, 성공하면 authProvider 상태가 loggedIn이 되어 app.dart가 이 오버레이를
/// 걷어낸다.
///
/// 아이디·비밀번호 가입/로그인과 소셜 로그인(카카오, iOS는 Apple)을 함께 제공한다.
/// 소셜로 처음 들어온 사람은 [OnboardingScreen]에서 캐릭터·닉네임을 고른다.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const _Landing()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 랜딩: 브랜드 + 회원가입/로그인 진입
// ─────────────────────────────────────────────────────────────

class _Landing extends StatelessWidget {
  const _Landing();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OunColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              const _BrandHeader(),
              const Spacer(flex: 4),
              _PrimaryButton(
                label: '회원가입',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const _SignupScreen()),
                ),
              ),
              const SizedBox(height: 10),
              const _SocialButtons(),
              const SizedBox(height: 18),
              // 이미 계정이 있는 경우 → 로그인
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const _LoginScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, color: OunColors.textMuted),
                      children: [
                        TextSpan(text: '이미 계정이 있으신가요?  '),
                        TextSpan(
                            text: '로그인',
                            style: TextStyle(
                                color: OunColors.tabAccent,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카카오로 시작하기 + (iOS) Apple로 계속하기.
/// 브랜드 가이드: 카카오는 노란 바탕 #FEE500·검은 글씨, Apple은 검은 바탕·흰 글씨.
class _SocialButtons extends ConsumerStatefulWidget {
  const _SocialButtons();

  @override
  ConsumerState<_SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends ConsumerState<_SocialButtons> {
  String? _busy; // 'kakao' | 'apple'

  Future<void> _go(String which) async {
    if (_busy != null) return;
    if (which == 'kakao' && !kakaoReady) {
      OunToast.show(context, '카카오 로그인은 곧 열려요');
      return;
    }
    setState(() => _busy = which);
    final auth = ref.read(authProvider.notifier);
    final ok = await (which == 'kakao'
        ? auth.signInWithKakao()
        : auth.signInWithApple());
    if (!mounted) return;
    setState(() => _busy = null);
    // 성공하면 오버레이가 걷히고, 취소는 조용히 넘어간다.
    final error = ref.read(authProvider).error;
    if (!ok && error != null) OunToast.show(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialButton(
          label: '카카오로 시작하기',
          icon: Icons.chat_bubble,
          background: const Color(0xFFFEE500),
          foreground: const Color(0xD9000000),
          busy: _busy == 'kakao',
          onPressed: () => _go('kakao'),
        ),
        if (appleSignInSupported) ...[
          const SizedBox(height: 10),
          _SocialButton(
            label: 'Apple로 계속하기',
            icon: Icons.apple,
            background: Colors.black,
            foreground: Colors.white,
            busy: _busy == 'apple',
            onPressed: () => _go('apple'),
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 소셜 첫 가입: 함께할 캐릭터 + 닉네임
// ─────────────────────────────────────────────────────────────

/// 소셜 로그인으로 방금 가입한 사람에게 한 번 보여 준다(app.dart 인증 게이트).
/// 닉네임은 카카오·애플 이름으로 미리 채워 두고, 캐릭터는 여기서 고른다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _nickname = TextEditingController(
    text: ref.read(authProvider).profile?.nickname ?? '',
  );
  String _gender = 'f';
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  bool get _valid =>
      RegExp(r'^[a-zA-Z0-9_가-힣]{1,20}$').hasMatch(_nickname.text.trim());

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      final profile = await ref.read(apiClientProvider).updateMe(
            nickname: _nickname.text.trim(),
            gender: _gender,
          );
      ref.invalidate(profileProvider);
      ref.read(authProvider.notifier).completeOnboarding(profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      OunToast.show(context, apiErrorMessage(e, '저장하지 못했어요. 다시 시도해 주세요'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OunColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('반가워요!',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: OunColors.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('함께할 캐릭터와 친구들이 찾을 닉네임을 정해 주세요',
                  style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
              const SizedBox(height: 26),
              const _SectionLabel('함께할 캐릭터'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CharacterCard(
                      selected: _gender == 'f',
                      label: '여자 아이',
                      icon: Icons.face_3,
                      onTap: () => setState(() => _gender = 'f'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CharacterCard(
                      selected: _gender == 'm',
                      label: '남자 아이',
                      icon: Icons.face_6,
                      onTap: () => setState(() => _gender = 'm'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionLabel('닉네임'),
              const SizedBox(height: 8),
              _AuthField(
                controller: _nickname,
                hint: '한글·영문·숫자·밑줄 20자 이내',
                textInputAction: TextInputAction.done,
                onChanged: () => setState(() {}),
                onSubmitted: _submit,
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('친구들이 @닉네임으로 나를 찾아요. 나중에 설정에서 바꿀 수 있어요.',
                    style: TextStyle(fontSize: 11.5, color: OunColors.textFaint)),
              ),
              const SizedBox(height: 26),
              _PrimaryButton(
                label: '시작하기',
                busy: _busy,
                onPressed: _valid && !_busy ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 회원가입: 함께할 캐릭터 선택 + 닉네임
// ─────────────────────────────────────────────────────────────

class _SignupScreen extends ConsumerStatefulWidget {
  const _SignupScreen();

  @override
  ConsumerState<_SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<_SignupScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  String _gender = 'f';
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  bool get _valid {
    final id = _username.text.trim();
    return RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(id) &&
        _password.text.length >= 6 &&
        _nickname.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(authProvider.notifier).signUp(
          username: _username.text.trim(),
          password: _password.text,
          nickname: _nickname.text.trim(),
          gender: _gender,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    // 성공하면 오버레이가 통째로 사라지므로 별도 이동은 필요 없다.
    if (!ok) {
      OunToast.show(context, ref.read(authProvider).error ?? '회원가입에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '회원가입',
      children: [
        const SizedBox(height: 8),
        const _SectionLabel('함께할 캐릭터'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CharacterCard(
                selected: _gender == 'f',
                label: '여자 아이',
                icon: Icons.face_3,
                onTap: () => setState(() => _gender = 'f'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CharacterCard(
                selected: _gender == 'm',
                label: '남자 아이',
                icon: Icons.face_6,
                onTap: () => setState(() => _gender = 'm'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionLabel('아이디'),
        const SizedBox(height: 8),
        _AuthField(
          controller: _username,
          hint: '영문·숫자·밑줄 4~20자',
          onChanged: () => setState(() {}),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('비밀번호'),
        const SizedBox(height: 8),
        _AuthField(
          controller: _password,
          hint: '6자 이상',
          obscure: true,
          maxLength: 72,
          onChanged: () => setState(() {}),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('닉네임'),
        const SizedBox(height: 8),
        _AuthField(
          controller: _nickname,
          hint: '예: 오운러버',
          textInputAction: TextInputAction.done,
          onChanged: () => setState(() {}),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('친구들이 찾을 이름이에요. 아이디와 달라도 돼요.',
              style: TextStyle(fontSize: 11.5, color: OunColors.textFaint)),
        ),
        const SizedBox(height: 26),
        _PrimaryButton(
          label: '가입하고 시작하기',
          busy: _busy,
          onPressed: _valid && !_busy ? _submit : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 로그인: 기존 닉네임
// ─────────────────────────────────────────────────────────────

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();

  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      _username.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(authProvider.notifier)
        .logIn(_username.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      OunToast.show(context, ref.read(authProvider).error ?? '로그인에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '로그인',
      children: [
        const SizedBox(height: 8),
        const _SectionLabel('아이디'),
        const SizedBox(height: 8),
        _AuthField(
          controller: _username,
          hint: '아이디',
          onChanged: () => setState(() {}),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('비밀번호'),
        const SizedBox(height: 8),
        _AuthField(
          controller: _password,
          hint: '비밀번호',
          obscure: true,
          maxLength: 72,
          textInputAction: TextInputAction.done,
          onChanged: () => setState(() {}),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 26),
        _PrimaryButton(
          label: '로그인',
          busy: _busy,
          onPressed: _valid && !_busy ? _submit : null,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const _SignupScreen()),
            ),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 13, color: OunColors.textMuted),
                children: [
                  TextSpan(text: '계정이 없으신가요?  '),
                  TextSpan(
                      text: '회원가입',
                      style: TextStyle(
                          color: OunColors.tabAccent,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 공통 위젯
// ─────────────────────────────────────────────────────────────

/// 회원가입/로그인 공통 뼈대: 뒤로가기 + 타이틀 + 폼.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: OunColors.textPrimary),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: OunColors.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Center(
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
              style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 12, color: OunColors.textMuted));
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    this.obscure = false,
    this.maxLength = 20,
    this.textInputAction = TextInputAction.next,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final bool obscure;
  final int maxLength;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
      obscureText: obscure,
      maxLength: maxLength,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 15, color: OunColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: OunColors.textFaint),
        counterText: '',
        filled: true,
        fillColor: OunColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OunColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OunColors.tabAccent),
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: selected ? OunColors.tabAccent : OunColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? OunColors.tabAccent : OunColors.cardBorder,
              width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 40,
                color: selected ? OunColors.onTabAccent : OunColors.tabAccent),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: OunColors.tabAccent,
        foregroundColor: OunColors.onTabAccent,
        disabledBackgroundColor: OunColors.cardBorder,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: OunColors.onTabAccent))
          : Text(label,
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
    );
  }
}
