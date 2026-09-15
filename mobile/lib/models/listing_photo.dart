import 'package:flutter/foundation.dart';

@immutable
class ListingPhoto {
  const ListingPhoto({
    required this.id,
    required this.url,
    required this.sortOrder,
  });

  final int id;
  final String url;
  final int sortOrder;

  factory ListingPhoto.fromJson(Map<String, dynamic> json) {
    return ListingPhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      sortOrder: json['sort_order'] as int,
    );
  }
}
