import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';

void main() {
  group('PaginatedResponse.fromJson', () {
    test('parses data and meta correctly', () {
      final json = {
        'data': [
          {'value': 1},
          {'value': 2},
        ],
        'links': {'first': 'a', 'last': 'b', 'prev': null, 'next': 'c'},
        'meta': {
          'current_page': 1,
          'from': 1,
          'last_page': 3,
          'per_page': 20,
          'to': 2,
          'total': 42,
        },
      };

      final response = PaginatedResponse.fromJson(
        json,
        (item) => item['value'] as int,
      );

      expect(response.data, [1, 2]);
      expect(response.currentPage, 1);
      expect(response.lastPage, 3);
      expect(response.total, 42);
      expect(response.hasMorePages, isTrue);
    });

    test('hasMorePages is false on the last page', () {
      final json = {
        'data': <dynamic>[],
        'meta': {'current_page': 3, 'last_page': 3, 'total': 42},
      };

      final response = PaginatedResponse.fromJson(json, (item) => item);

      expect(response.hasMorePages, isFalse);
    });
  });
}
