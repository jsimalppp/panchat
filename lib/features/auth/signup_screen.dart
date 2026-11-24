import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/misc.dart';
import '../../data/providers.dart';
import 'auth_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final email = _email.text.trim();
    try {
      final res = await ref.read(supabaseProvider).auth.signUp(
        email: email,
        password: _password.text,
        data: {
          'username': _username.text.trim().toLowerCase(),
          'display_name': _name.text.trim(),
        },
      );
      if (!mounted) return;
      if (res.session == null) {
        context.go('/verify?email=${Uri.encodeQueryComponent(email)}');
      }
      // If a session exists the router sends the user to profile setup.
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
      title: context.tr('signup'),
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: context.tr('displayName')),
              validator: (v) => requiredValidator(context, v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              autocorrect: false,
              decoration: InputDecoration(labelText: context.tr('username'), prefixText: '@'),
              validator: (v) => isValidUsername((v ?? '').trim().toLowerCase())
                  ? null
                  : context.tr('usernameInvalid'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: context.tr('email')),
              validator: (v) => requiredValidator(context, v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: context.tr('password')),
              validator: (v) => passwordValidator(context, v),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(context.tr('signup')),
        ),
        TextButton(onPressed: () => context.go('/login'), child: Text(context.tr('haveAccount'))),
      ],
    );
  }
}
