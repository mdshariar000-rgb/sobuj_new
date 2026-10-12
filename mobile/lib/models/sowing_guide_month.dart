import 'package:flutter/foundation.dart';

/// Mirrors SowingGuideMonthResource on the backend — one month of the UK
/// sowing guide behind "What can you grow now?". Edited only in the admin
/// panel (Content → What Can You Grow).
@immutable
class SowingGuideMonth {
  const SowingGuideMonth({
    required this.month,
    required this.outdoors,
    required this.underCover,
  });

  /// 1 (January) to 12 (December).
  final int month;
  final List<String> outdoors;
  final List<String> underCover;

  factory SowingGuideMonth.fromJson(Map<String, dynamic> json) {
    List<String> names(Object? list) =>
        ((list as List<dynamic>?) ?? const []).cast<String>();

    return SowingGuideMonth(
      month: json['month'] as int,
      outdoors: names(json['outdoors']),
      underCover: names(json['under_cover']),
    );
  }
}
