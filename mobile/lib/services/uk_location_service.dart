import 'package:dio/dio.dart';

import '../models/uk_location.dart';

/// Searches UK places and postcodes via postcodes.io — a free, no-API-key
/// service backed by Ordnance Survey and ONS open data. Covers every town,
/// village and suburb by name, every live postcode ("LS6 3AA"), and every
/// postcode district ("LS6").
class UkLocationService {
  UkLocationService([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _baseUrl = 'https://api.postcodes.io';

  static final _fullPostcode = RegExp(
    r'^[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}$',
    caseSensitive: false,
  );
  static final _outcode = RegExp(
    r'^[A-Z]{1,2}\d[A-Z\d]?$',
    caseSensitive: false,
  );

  /// One full UK postcode, or null if postcodes.io doesn't know it.
  Future<UkLocation?> lookupPostcode(String postcode) async {
    final q = postcode.trim();
    if (!_fullPostcode.hasMatch(q)) return null;
    try {
      final results = await _postcode(q);
      return results.isEmpty ? null : results.first;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<UkLocation>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    try {
      if (_fullPostcode.hasMatch(q)) return await _postcode(q);
      if (_outcode.hasMatch(q)) return await _outcodeLookup(q);
      return await _places(q);
    } on DioException catch (e) {
      // postcodes.io answers an unknown postcode/outcode with a 404, which
      // just means "no matches" here.
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<List<UkLocation>> _postcode(String q) async {
    final response = await _dio.get(
      '$_baseUrl/postcodes/${Uri.encodeComponent(q)}',
    );
    final result = response.data['result'] as Map<String, dynamic>;
    return [
      UkLocation(
        name: result['postcode'] as String,
        detail: _join([
          result['admin_ward'],
          result['admin_district'],
          result['country'],
        ]),
        latitude: (result['latitude'] as num).toDouble(),
        longitude: (result['longitude'] as num).toDouble(),
        town: result['admin_district'] as String?,
        county: result['admin_county'] as String?,
      ),
    ];
  }

  Future<List<UkLocation>> _outcodeLookup(String q) async {
    final response = await _dio.get(
      '$_baseUrl/outcodes/${Uri.encodeComponent(q)}',
    );
    final result = response.data['result'] as Map<String, dynamic>;
    final districts = (result['admin_district'] as List).cast<String>();
    final countries = (result['country'] as List).cast<String>();
    return [
      UkLocation(
        name: result['outcode'] as String,
        detail: _join([...districts.take(2), ...countries.take(1)]),
        latitude: (result['latitude'] as num).toDouble(),
        longitude: (result['longitude'] as num).toDouble(),
      ),
    ];
  }

  Future<List<UkLocation>> _places(String q) async {
    final response = await _dio.get(
      '$_baseUrl/places',
      queryParameters: {'q': q, 'limit': 10},
    );
    final results = (response.data['result'] as List?) ?? const [];
    return results.cast<Map<String, dynamic>>().map((place) {
      final name = place['name_1'] as String;
      final area = place['district_borough'] ?? place['county_unitary'];
      return UkLocation(
        name: name,
        // "Manchester, Manchester, England" reads badly — drop the repeat.
        detail: _join([if (area != name) area, place['country']]),
        latitude: (place['latitude'] as num).toDouble(),
        longitude: (place['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  static String _join(List<Object?> parts) => parts
      .whereType<String>()
      .where((part) => part.isNotEmpty)
      .toSet()
      .join(', ');
}
