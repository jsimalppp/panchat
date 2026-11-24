import 'package:intl/intl.dart';

String formatChatTime(DateTime t) {
  final now = DateTime.now();
  final l = t.toLocal();
  if (l.year == now.year && l.month == now.month && l.day == now.day) {
    return DateFormat('HH:mm').format(l);
  }
  if (now.difference(l).inDays < 7) return DateFormat('EEE').format(l);
  return DateFormat('dd/MM/yy').format(l);
}

String formatClock(DateTime t) => DateFormat('HH:mm').format(t.toLocal());

String formatDuration(int ms) {
  final s = (ms / 1000).round();
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

final RegExp _usernameRe = RegExp(r'^[a-z0-9_]{3,24}$');

bool isValidUsername(String v) => _usernameRe.hasMatch(v);

String sanitizeUsernameQuery(String v) =>
    v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
