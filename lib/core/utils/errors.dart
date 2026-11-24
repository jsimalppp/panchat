import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/strings.dart';

/// Turns any exception into a short, friendly message. Never shows raw JSON
/// or technical text to the user.
String friendlyError(BuildContext c, Object e) {
  if (e is SocketException || e is TimeoutException) return c.tr('errNetwork');
  if (e is AuthException) {
    final code = (e.code ?? '').toLowerCase();
    final msg = e.message.toLowerCase();
    if (code == 'user_already_exists' || code == 'email_exists' ||
        msg.contains('already registered') || msg.contains('already been registered')) {
      return c.tr('errEmailTaken');
    }
    if (code == 'invalid_credentials' || msg.contains('invalid login')) return c.tr('errBadLogin');
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) return c.tr('errNotConfirmed');
    if (code == 'otp_expired' || code == 'otp_disabled' || msg.contains('expired') ||
        msg.contains('invalid') && msg.contains('token')) {
      return c.tr('errBadCode');
    }
    if (code == 'weak_password' || msg.contains('password should')) return c.tr('passwordShort');
    if (code.contains('rate_limit') || msg.contains('rate limit') || msg.contains('seconds')) {
      return c.tr('errRateLimit');
    }
    if (code == 'validation_failed' || msg.contains('invalid format') || msg.contains('valid email')) {
      return c.tr('errBadEmail');
    }
    if (msg.contains('database error saving new user')) return c.tr('errUsernameTaken');
    if (msg.contains('socket') || msg.contains('network') || msg.contains('failed host')) {
      return c.tr('errNetwork');
    }
    return c.tr('errGeneric');
  }
  if (e is PostgrestException) {
    if (e.code == '23505') return c.tr('errUsernameTaken');
    return c.tr('errGeneric');
  }
  return c.tr('errGeneric');
}
