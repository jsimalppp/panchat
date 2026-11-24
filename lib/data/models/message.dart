class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.body,
    this.mediaPath,
    this.durationMs,
    this.replyTo,
    this.deletedAt,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String type; // text | image | voice
  final String? body;
  final String? mediaPath;
  final int? durationMs;
  final String? replyTo;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final bool pending;
  final bool failed;

  bool get isDeleted => deletedAt != null;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        senderId: j['sender_id'] as String,
        type: j['type'] as String,
        body: j['body'] as String?,
        mediaPath: j['media_path'] as String?,
        durationMs: j['media_duration_ms'] as int?,
        replyTo: j['reply_to'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        deletedAt: j['deleted_at'] == null
            ? null
            : DateTime.parse(j['deleted_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type,
        if (body != null) 'body': body,
        if (mediaPath != null) 'media_path': mediaPath,
        if (durationMs != null) 'media_duration_ms': durationMs,
        if (replyTo != null) 'reply_to': replyTo,
      };

  Message copyWith({bool? pending, bool? failed, DateTime? deletedAt, DateTime? createdAt}) =>
      Message(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        body: body,
        mediaPath: mediaPath,
        durationMs: durationMs,
        replyTo: replyTo,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );
}
