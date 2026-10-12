import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'event_enums.dart';
import 'group.dart';

/// Mirrors EventResource on the backend.
@immutable
class Event {
  const Event({
    required this.id,
    this.groupId,
    required this.title,
    this.description,
    required this.format,
    this.category,
    this.coverImageUrl,
    this.location,
    required this.startsAt,
    this.endsAt,
    this.capacity,
    this.registrationFee,
    this.proposedDates = const [],
    required this.status,
    this.attendeesCount,
    this.attendeesPreview,
    this.isSaved,
    this.host,
    this.group,
    this.myRsvpStatus,
    this.isNearYou,
    required this.createdAt,
  });

  final int id;
  final int? groupId;
  final String title;
  final String? description;
  final EventFormat format;

  /// The admin-managed category name this event was tagged with (see
  /// EventCategory on the backend) — null means the host didn't pick one.
  final String? category;
  final String? coverImageUrl;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? capacity;

  /// Shown to attendees; paid at the door, not through the app. Null or
  /// zero means free.
  final double? registrationFee;

  /// Other dates the host is considering, besides [startsAt].
  final List<DateTime> proposedDates;
  final EventStatus status;
  final int? attendeesCount;

  /// A small preview of real attendees (newest RSVP first) — only present
  /// when the backend eager-loaded the full `attendees` relation, i.e. the
  /// single-event GET /events/{id} response, not the paginated list — see
  /// EventResource::attendees_preview on the backend.
  final List<AppUser>? attendeesPreview;

  /// Null just means "not loaded" (e.g. from the paginated list) — treat the
  /// same as false in the UI. See EventController::save()/unsave().
  final bool? isSaved;

  final AppUser? host;

  /// Only present when the event belongs to a group and that relation was
  /// eager-loaded — see EventResource::group on the backend (true for every
  /// endpoint this app calls).
  final Group? group;

  /// Only present when authenticated and attendees were eager-loaded — see
  /// EventResource::my_rsvp_status on the backend. Null also just means "no
  /// RSVP yet", not just "not loaded" — treat both the same in the UI.
  final EventAttendeeStatus? myRsvpStatus;

  /// Only from GET /events: the place mentions the viewer's city.
  final bool? isNearYou;

  final DateTime createdAt;

  Event copyWith({
    int? attendeesCount,
    EventAttendeeStatus? myRsvpStatus,
    bool clearRsvp = false,
    bool? isSaved,
  }) {
    return Event(
      id: id,
      groupId: groupId,
      title: title,
      description: description,
      format: format,
      category: category,
      coverImageUrl: coverImageUrl,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      capacity: capacity,
      registrationFee: registrationFee,
      proposedDates: proposedDates,
      status: status,
      attendeesCount: attendeesCount ?? this.attendeesCount,
      attendeesPreview: attendeesPreview,
      isSaved: isSaved ?? this.isSaved,
      host: host,
      group: group,
      myRsvpStatus: clearRsvp ? null : (myRsvpStatus ?? this.myRsvpStatus),
      isNearYou: isNearYou,
      createdAt: createdAt,
    );
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      groupId: json['group_id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      format: EventFormat.fromValue(json['format'] as String),
      category: json['category'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      location: json['location'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      capacity: json['capacity'] as int?,
      registrationFee: (json['registration_fee'] as num?)?.toDouble(),
      proposedDates: (json['proposed_dates'] as List<dynamic>? ?? const [])
          .map((date) => DateTime.parse(date as String))
          .toList(),
      status: EventStatus.fromValue(json['status'] as String),
      attendeesCount: json['attendees_count'] as int?,
      attendeesPreview: (json['attendees_preview'] as List<dynamic>?)
          ?.map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      isSaved: json['is_saved'] as bool?,
      host: json['host'] != null
          ? AppUser.fromJson(json['host'] as Map<String, dynamic>)
          : null,
      group: json['group'] != null
          ? Group.fromJson(json['group'] as Map<String, dynamic>)
          : null,
      myRsvpStatus: json['my_rsvp_status'] != null
          ? EventAttendeeStatus.fromValue(json['my_rsvp_status'] as String)
          : null,
      isNearYou: json['is_near_you'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
