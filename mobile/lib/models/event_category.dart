import 'package:flutter/foundation.dart';

/// Mirrors EventCategoryResource on the backend — an admin-managed category
/// an event can be tagged with, picked from a list rather than typed
/// freely. Backs the Events tab's filter chips and the "create an event"
/// form's category picker. Created/edited only via the admin panel — see
/// EventCategoryResource (Filament) and EventCategoryController::index()
/// on the backend.
@immutable
class EventCategory {
  const EventCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory EventCategory.fromJson(Map<String, dynamic> json) {
    return EventCategory(id: json['id'] as int, name: json['name'] as String);
  }
}
