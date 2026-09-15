import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'listing.dart';

/// Mirrors App\Enums\SwapOfferStatus on the backend.
enum SwapOfferStatus {
  pending('pending', 'Pending'),
  countered('countered', 'Countered'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined'),
  completed('completed', 'Completed'),
  canceled('canceled', 'Canceled');

  const SwapOfferStatus(this.value, this.label);

  final String value;
  final String label;

  /// Mirrors App\Enums\SwapOfferStatus::isFinal() — Accepted still awaits a
  /// real-world handover, so it counts as open for the Messages badge.
  bool get isOpen => switch (this) {
    SwapOfferStatus.pending ||
    SwapOfferStatus.countered ||
    SwapOfferStatus.accepted => true,
    SwapOfferStatus.declined ||
    SwapOfferStatus.completed ||
    SwapOfferStatus.canceled => false,
  };

  static SwapOfferStatus fromValue(String value) {
    return SwapOfferStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () =>
          throw FormatException('Unknown SwapOfferStatus value: $value'),
    );
  }
}

/// A lightweight preview of a thread's most recent message — real data from
/// SwapOfferResource's `last_message` (an eager-loaded `latestOfMany()`
/// relation on the backend), not fabricated read/unread state.
@immutable
class SwapOfferLastMessage {
  const SwapOfferLastMessage({
    this.body,
    required this.hasImage,
    required this.isSystemEvent,
    this.senderId,
    required this.createdAt,
  });

  final String? body;
  final bool hasImage;
  final bool isSystemEvent;

  /// Null for a system-event message.
  final int? senderId;
  final DateTime createdAt;

  factory SwapOfferLastMessage.fromJson(Map<String, dynamic> json) {
    return SwapOfferLastMessage(
      body: json['body'] as String?,
      hasImage: json['has_image'] as bool,
      isSystemEvent: json['is_system_event'] as bool,
      senderId: json['sender_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Mirrors SwapOfferResource on the backend — a "Contact"/"Request"/"Propose
/// Trade"/"I Have This" action creates one of these against someone else's
/// listing, kicking off its own message thread.
@immutable
class SwapOffer {
  const SwapOffer({
    required this.id,
    required this.status,
    this.note,
    this.listing,
    this.requester,
    this.lastMessage,
    this.unreadCount,
    required this.createdAt,
  });

  final int id;
  final SwapOfferStatus status;

  /// The free-text note from offer_details.note, if any.
  final String? note;
  final Listing? listing;
  final AppUser? requester;

  /// Null for a brand-new offer whose only message (the system "X made an
  /// offer" event) hasn't loaded yet, or when this SwapOffer came from an
  /// endpoint that doesn't eager-load it (e.g. the create/status-update
  /// response).
  final SwapOfferLastMessage? lastMessage;

  /// Real count of messages from the other party not yet marked read — see
  /// MessageController::index() (opening the thread marks them read) and
  /// SwapOfferResource::unread_count. Null when the endpoint didn't compute
  /// it (create/status-update responses), not "zero".
  final int? unreadCount;
  final DateTime createdAt;

  SwapOffer copyWith({SwapOfferStatus? status, int? unreadCount}) {
    return SwapOffer(
      id: id,
      status: status ?? this.status,
      note: note,
      listing: listing,
      requester: requester,
      lastMessage: lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
    );
  }

  factory SwapOffer.fromJson(Map<String, dynamic> json) {
    final offerDetails = json['offer_details'] as Map<String, dynamic>?;

    return SwapOffer(
      id: json['id'] as int,
      status: SwapOfferStatus.fromValue(json['status'] as String),
      note: offerDetails?['note'] as String?,
      listing: json['listing'] != null
          ? Listing.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
      requester: json['requester'] != null
          ? AppUser.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      lastMessage: json['last_message'] != null
          ? SwapOfferLastMessage.fromJson(
              json['last_message'] as Map<String, dynamic>,
            )
          : null,
      unreadCount: json['unread_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
