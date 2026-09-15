import 'package:flutter/foundation.dart';

import 'enums.dart';

/// Mirrors GroupMemberResource on the backend — a user in the context of one
/// group's real membership (their real pivot role and join date), not the
/// fuller AppUser shape (no email/location/etc — this is a public roster).
@immutable
class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    required this.isVerified,
    this.experienceLevel,
    this.growingSetup,
    required this.isAdmin,
    required this.joinedAt,
  });

  final int id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final bool isVerified;
  final ExperienceLevel? experienceLevel;
  final GrowingSetup? growingSetup;

  /// From the real group_members.role pivot — 'admin' vs 'member'.
  final bool isAdmin;
  final DateTime? joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      experienceLevel: json['experience_level'] != null
          ? ExperienceLevel.fromValue(json['experience_level'] as String)
          : null,
      growingSetup: json['growing_setup'] != null
          ? GrowingSetup.fromValue(json['growing_setup'] as String)
          : null,
      isAdmin: json['role'] == 'admin',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
    );
  }
}
