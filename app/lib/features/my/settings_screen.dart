import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/providers.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 설정: 프로필(이름·닉네임), 계정(로그아웃·회원 탈퇴).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// 로그아웃·탈퇴 전에 쌓인 화면을 걷는다. 다시 로그인했을 때 설정 화면이
  /// 남아 있지 않도록(로그인 화면은 라우터 위를 덮기만 한다).
  static void _popToRoot(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initial,
    required String hint,
    String prefix = '',
    required bool nickname,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextEditSheet(
        title: title,
        initial: initial,
        hint: hint,
        prefix: prefix,
      ),
    );
    if (value == null || value == initial || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await ref.read(apiClientProvider).updateMe(
            nickname: nickname ? value : null,
            displayName: nickname ? null : value,
          );
      ref.read(authProvider.notifier).updateProfile(profile);
      ref.invalidate(profileProvider);
      OunToast.showWith(messenger, '$title을 바꿨어요', kind: OunToastKind.success);
    } catch (e) {
      OunToast.showWith(messenger, apiErrorMessage(e, '$title을 바꾸지 못했어요'));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).deleteAccount();
      if (context.mounted) _popToRoot(context);
      await ref.read(authProvider.notifier).logout();
      OunToast.showWith(messenger, '그동안 함께해 줘서 고마워요');
    } catch (e) {
      OunToast.showWith(messenger, apiErrorMessage(e, '탈퇴하지 못했어요. 잠시 후 다시 시도해 주세요'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('설정',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          const _SectionLabel('프로필'),
          _Group(children: [
            _Row(
              title: '이름',
              value: profile?.displayName ?? '…',
              onTap: profile == null
                  ? null
                  : () => _edit(context, ref,
                      title: '이름',
                      initial: profile.displayName,
                      hint: '친구들에게 보일 이름',
                      nickname: false),
            ),
            _Row(
              title: '닉네임',
              value: profile == null ? '…' : '@${profile.nickname}',
              last: true,
              onTap: profile == null
                  ? null
                  : () => _edit(context, ref,
                      title: '닉네임',
                      initial: profile.nickname,
                      hint: '한글·영문·숫자·밑줄 20자 이내',
                      prefix: '@',
                      nickname: true),
            ),
          ]),
          const SizedBox(height: 18),
          const _SectionLabel('계정'),
          _Group(children: [
            _Row(
              title: '로그아웃',
              onTap: () {
                _popToRoot(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
            _Row(
              title: '회원 탈퇴',
              destructive: true,
              last: true,
              onTap: () => _deleteAccount(context, ref),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 7),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OunColors.textMuted)),
      );
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

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.value,
    this.onTap,
    this.last = false,
    this.destructive = false,
  });

  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool last;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: OunColors.cardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: destructive
                            ? const Color(0xFFC0533F)
                            : OunColors.textPrimary)),
              ),
              if (value != null)
                Text(value!,
                    style: const TextStyle(
                        fontSize: 13, color: OunColors.textMuted)),
              if (!destructive) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: OunColors.textFaint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 한 줄 입력 시트(이름·닉네임). 저장하면 다듬은 값을 돌려준다.
class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.initial,
    required this.hint,
    this.prefix = '',
  });

  final String title;
  final String initial;
  final String hint;
  final String prefix;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    return _Sheet(
      children: [
        Text('${widget.title} 바꾸기',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OunColors.textPrimary)),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 20,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixText: widget.prefix.isEmpty ? null : widget.prefix,
            hintStyle: const TextStyle(color: OunColors.textFaint),
            filled: true,
            fillColor: OunColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: OunColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: OunColors.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SheetButton(
          label: '저장',
          onPressed:
              value.isEmpty ? null : () => Navigator.of(context).pop(value),
        ),
      ],
    );
  }
}

/// 회원 탈퇴 확인: 무엇이 지워지는지 알리고, '탈퇴'를 입력해야 버튼이 켜진다.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      children: [
        const Text('정말 떠나시나요?',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OunColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
          '운동 기록, 코인과 아이템, 캐릭터, 친구와 응원, 크루 글이 모두 지워지고 '
          '되돌릴 수 없어요. 내가 방장인 크루는 가장 오래된 멤버에게 넘어가요.',
          style:
              TextStyle(fontSize: 13, height: 1.5, color: OunColors.textMuted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: "확인을 위해 '탈퇴'라고 입력해 주세요",
            hintStyle: const TextStyle(color: OunColors.textFaint),
            filled: true,
            fillColor: OunColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: OunColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: OunColors.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SheetButton(
          label: '탈퇴하기',
          destructive: true,
          onPressed: _controller.text.trim() == '탈퇴'
              ? () => Navigator.of(context).pop(true)
              : null,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('계속 함께할게요',
              style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
      ],
    );
  }
}

/// 둥근 상단·핸들바 시트. 키보드가 올라오면 함께 올라간다.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: OunColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: OunColors.cardBorder,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            destructive ? const Color(0xFFC0533F) : OunColors.tabAccent,
        foregroundColor: OunColors.onTabAccent,
        disabledBackgroundColor: OunColors.card,
        disabledForegroundColor: OunColors.textFaint,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
    );
  }
}
