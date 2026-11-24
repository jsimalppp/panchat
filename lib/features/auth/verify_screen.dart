import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets/misc.dart';
import '../../data/providers.dart';
import 'auth_widgets.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.email});
  final String email;
  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) return;
    setState(() => _busy = true);
    try {
      await ref.read(supabaseProvider).auth.verifyOTP(
            email: widget.email,
            token: code,
            type: OtpType.signup,
          );
      // Session is now set; the router moves on to profile setup.
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(supabaseProvider).auth.resend(type: OtpType.signup, email: widget.email);
      if (mounted) showSnack(context, context.tr('codeSent'));
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('verifyTitle'),
      children: [
        Text('${context.tr('verifyHint')}\n${widget.email}'),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          style: const TextStyle(fontSize: 26, letterSpacing: 8),
          decoration: InputDecoration(labelText: context.tr('code'), counterText: ''),
          onChanged: (v) {
            if (v.trim().length >= 6 && !_busy) _verify();
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(context.tr('verify')),
        ),
        TextButton(onPressed: _resend, child: Text(context.tr('resend'))),
        TextButton(onPressed: () => context.go('/login'), child: Text(context.tr('login'))),
      ],
    );
  }
}
