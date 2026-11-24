import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('🐼', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
                  Text(context.tr('appName'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: PandaColors.bambooDark)),
                  const SizedBox(height: 4),
                  Text(context.tr('tagline'), textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  Text(title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? requiredValidator(BuildContext c, String? v) =>
    (v == null || v.trim().isEmpty) ? c.tr('required') : null;

String? passwordValidator(BuildContext c, String? v) {
  if (v == null || v.isEmpty) return c.tr('required');
  if (v.length < 8) return c.tr('passwordShort');
  return null;
}
