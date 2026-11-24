import 'message.dart';
import 'profile.dart';

class ChatSummary {
  ChatSummary({
    required this.id,
    required this.isGroup,
    required this.title,
    required this.lastMessageAt,
    this.avatarUrl,
    this.other,
    this.lastMessage,
    this.unread = 0,
  });

  final String id;
  final bool isGroup;
  final String title;
  final String? avatarUrl;
  final Profile? other;
  final Message? lastMessage;
  final int unread;
  final DateTime lastMessageAt;
}
