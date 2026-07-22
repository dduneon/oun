import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 인증(로그인/회원가입) 오버레이. 자체 Navigator로 랜딩 → 회원가입/로그인을
/// 오가며, 성공하면 authProvider 상태가 loggedIn이 되어 app.dart가 이 오버레이를
/// 걷어낸다.
///
/// 실 인증은 카카오 로그인(백엔드 POST /auth/kakao 준비됨). 그전까지 dev 인증으로
/// 닉네임 기반 회원가입/로그인을 제공한다.
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
              // 카카오 로그인 자리(백엔드 POST /auth/kakao 준비됨, 앱 SDK 연동 예정)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: OunColors.textPrimary,
                  side: const BorderSide(color: OunColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => OunToast.show(context, '카카오 로그인은 곧 열려요'),
                icon: const Icon(Icons.chat_bubble, size: 17),
                label: const Text('카카오로 시작하기',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
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

// ─────────────────────────────────────────────────────────────
// 회원가입: 함께할 캐릭터 선택 + 닉네임
// ─────────────────────────────────────────────────────────────

class _SignupScreen extends ConsumerStatefulWidget {
  const _SignupScreen();

  @override
  ConsumerState<_SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<_SignupScreen> {
  final _nickname = TextEditingController();
  String _gender = 'f';
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(authProvider.notifier).signUp(nickname, _gender);
    if (!mounted) return;
    setState(() => _busy = false);
    // 성공하면 오버레이가 통째로 사라지므로 별도 이동은 필요 없다.
    if (!ok) {
      OunToast.show(context, ref.read(authProvider).error ?? '회원가입에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nickname.text.trim().isNotEmpty && !_busy;
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
        const _SectionLabel('닉네임'),
        const SizedBox(height: 8),
        _NicknameField(
          controller: _nickname,
          hint: '예: oun_dduneon',
          onChanged: () => setState(() {}),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('친구들이 찾을 이름이에요. 나중에 바꿀 수 있어요.',
              style: TextStyle(fontSize: 11.5, color: OunColors.textFaint)),
        ),
        const SizedBox(height: 26),
        _PrimaryButton(
          label: '가입하고 시작하기',
          busy: _busy,
          onPressed: canSubmit ? _submit : null,
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
  final _nickname = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(authProvider.notifier).logIn(nickname);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      OunToast.show(context, ref.read(authProvider).error ?? '로그인에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _nickname.text.trim().isNotEmpty && !_busy;
    return _AuthScaffold(
      title: '로그인',
      children: [
        const SizedBox(height: 8),
        const _SectionLabel('닉네임'),
        const SizedBox(height: 8),
        _NicknameField(
          controller: _nickname,
          hint: '가입한 닉네임',
          onChanged: () => setState(() {}),
          onSubmitted: _submit,
        ),
        const SizedBox(height: 26),
        _PrimaryButton(
          label: '로그인',
          busy: _busy,
          onPressed: canSubmit ? _submit : null,
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

class _NicknameField extends StatelessWidget {
  const _NicknameField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
      maxLength: 20,
      textInputAction: TextInputAction.done,
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
