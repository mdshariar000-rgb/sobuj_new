import 'package:flutter/foundation.dart';

/// Mirrors PostCategoryResource on the backend — an admin-managed category
/// a post can be tagged with, picked from a list rather than typed freely.
/// Backs the Home tab's Recent/Disease Alerts/Harvests chips and the "new
/// post" composer's category picker. Created/edited only via the admin
/// panel — see PostCategoryResource (Filament) and
/// PostCategoryController::index() on the backend.
@immutable
class PostCategory {
  const PostCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory PostCategory.fromJson(Map<String, dynamic> json) {
    return PostCategory(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
