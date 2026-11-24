import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/misc.dart';
import '../../data/providers.dart';
import 'auth_widgets.dart';

/// Password reset by email code: send code, then code + new password.
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});
  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(supabaseProvider).auth.resetPasswordForEmail(_email.text.trim());
      if (mounted) {
        setState(() => _codeSent = true);
        showSnack(context, context.tr('codeSent'));
      }
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_password.text.length < 8 || _code.text.trim().length < 6) {
      showSnack(context, context.tr('passwordShort'));
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(supabaseProvider).auth;
    try {
      await auth.verifyOTP(
        email: _email.text.trim(),
        token: _code.text.trim(),
        type: OtpType.recovery,
      );
      await auth.updateUser(UserAttributes(password: _password.text));
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('resetTitle'),
      children: [
        TextField(
          controller: _email,
          enabled: !_codeSent,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: context.tr('email')),
        ),
        const SizedBox(height: 12),
        if (_codeSent) ...[
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.tr('code')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: context.tr('newPassword')),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _reset, child: Text(context.tr('save'))),
        ] else
          FilledButton(onPressed: _busy ? null : _sendCode, child: Text(context.tr('sendCode'))),
        TextButton(onPressed: () => context.go('/login'), child: Text(context.tr('login'))),
      ],
    );
  }
}
