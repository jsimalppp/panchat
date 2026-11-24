class Profile {
  Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarPath,
    this.about,
    this.lastSeenAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarPath;
  final String? about;
  final DateTime? lastSeenAt;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String,
        avatarPath: j['avatar_path'] as String?,
        about: j['about'] as String?,
        lastSeenAt: j['last_seen_at'] == null
            ? null
            : DateTime.parse(j['last_seen_at'] as String),
      );
}
