import 'package:flutter/foundation.dart';

/// Mirrors ListingCategoryResource on the backend — an admin-managed
/// marketplace category a listing is tagged with, picked from a list rather
/// than typed freely. Created/edited only via the admin panel — see
/// ListingCategoryResource (Filament) and ListingCategoryController::index()
/// on the backend.
@immutable
class ListingCategory {
  const ListingCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory ListingCategory.fromJson(Map<String, dynamic> json) {
    return ListingCategory(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
