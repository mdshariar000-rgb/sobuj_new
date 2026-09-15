import 'package:flutter/foundation.dart';

/// Wraps a Laravel paginator's JSON shape: {"data": [...], "links": {...}, "meta": {...}}.
@immutable
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMorePages => currentPage < lastPage;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final meta = json['meta'] as Map<String, dynamic>;

    return PaginatedResponse(
      data: (json['data'] as List<dynamic>)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(growable: false),
      currentPage: meta['current_page'] as int,
      lastPage: meta['last_page'] as int,
      total: meta['total'] as int,
    );
  }
}
