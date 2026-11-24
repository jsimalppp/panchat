import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, required this.name, this.radius = 24, this.isGroup = false});
  final String? url;
  final String name;
  final double radius;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: PandaColors.bambooSoft,
      child: isGroup
          ? Icon(Icons.groups, color: PandaColors.bambooDark, size: radius)
          : Text(initial,
              style: TextStyle(
                  color: PandaColors.bambooDark,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      imageBuilder: (c, img) => CircleAvatar(radius: radius, backgroundImage: img),
      placeholder: (c, u) => fallback,
      errorWidget: (c, u, e) => fallback,
    );
  }
}
