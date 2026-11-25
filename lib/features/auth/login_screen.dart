import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/errors.dart';
import '../../core/widgets/misc.dart';
import '../../data/providers.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final typed = _email.text.trim();
    final email = typed;
    try {
      await ref.read(supabaseProvider).auth.signInWithPassword(
            email: email,
            password: _password.text,
          );
      // Router redirect takes over on the auth state change.
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('not confirmed')) {
        await ref.read(supabaseProvider).auth.resend(type: OtpType.signup, email: email);
        if (mounted) context.go('/verify?email=${Uri.encodeQueryComponent(email)}');
      } else {
        showSnack(context, friendlyError(context, e));
      }
    } catch (_) {
      if (mounted) showSnack(context, context.tr('error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('login'),
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: InputDecoration(labelText: context.tr('email')),
              validator: (v) => requiredValidator(context, v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: context.tr('password')),
              validator: (v) => requiredValidator(context, v),
              onFieldSubmitted: (_) => _submit(),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(context.tr('login')),
        ),
        TextButton(onPressed: () => context.go('/forgot'), child: Text(context.tr('forgot'))),
        TextButton(onPressed: () => context.go('/signup'), child: Text(context.tr('noAccount'))),
      ],
    );
  }
}
