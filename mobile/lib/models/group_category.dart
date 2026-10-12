import 'package:flutter/foundation.dart';

/// Mirrors GroupCategoryResource on the backend — an admin-managed category
/// a group can be tagged with, picked from a list rather than typed freely.
/// Created/edited only via the admin panel — see GroupCategoryResource
/// (Filament) and GroupCategoryController::index() on the backend.
@immutable
class GroupCategory {
  const GroupCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory GroupCategory.fromJson(Map<String, dynamic> json) {
    return GroupCategory(id: json['id'] as int, name: json['name'] as String);
  }
}
