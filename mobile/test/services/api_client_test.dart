import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ApiClient client;

  setUp(() {
    dio = MockDio();
    client = ApiClient(dio);
  });

  group('nearbyListings', () {
    test(
      'sends the expected query parameters and parses the response',
      () async {
        when(
          () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/listings/nearby'),
            statusCode: 200,
            data: {
              'data': <dynamic>[],
              'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
            },
          ),
        );

        await client.nearbyListings(
          latitude: 23.78,
          longitude: 90.27,
          radiusKm: 15,
          category: 'Seeds & Scions',
          transactionType: TransactionType.swap,
          search: '  tomato  ',
          page: 2,
        );

        final captured =
            verify(
                  () => dio.get(
                    '/listings/nearby',
                    queryParameters: captureAny(named: 'queryParameters'),
                  ),
                ).captured.single
                as Map<String, dynamic>;

        expect(captured['latitude'], 23.78);
        expect(captured['longitude'], 90.27);
        expect(captured['radius_km'], 15);
        expect(captured['category'], 'Seeds & Scions');
        expect(captured['transaction_type'], 'swap');
        expect(captured['q'], 'tomato');
        expect(captured['page'], 2);
      },
    );

    test('omits category, transaction_type, and q when not provided', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/listings/nearby'),
          statusCode: 200,
          data: {
            'data': <dynamic>[],
            'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
          },
        ),
      );

      await client.nearbyListings(latitude: 23.78, longitude: 90.27);

      final captured =
          verify(
                () => dio.get(
                  '/listings/nearby',
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured.containsKey('category'), isFalse);
      expect(captured.containsKey('transaction_type'), isFalse);
      expect(captured.containsKey('q'), isFalse);
    });

    test('an empty/blank search term is not sent as q', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/listings/nearby'),
          statusCode: 200,
          data: {
            'data': <dynamic>[],
            'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
          },
        ),
      );

      await client.nearbyListings(
        latitude: 23.78,
        longitude: 90.27,
        search: '   ',
      );

      final captured =
          verify(
                () => dio.get(
                  '/listings/nearby',
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured.containsKey('q'), isFalse);
    });

    test('a 401 response is surfaced as an ApiException', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/listings/nearby'),
          response: Response(
            requestOptions: RequestOptions(path: '/listings/nearby'),
            statusCode: 401,
            data: {'message': 'Unauthenticated.'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        client.nearbyListings(latitude: 23.78, longitude: 90.27),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
              .having((e) => e.message, 'message', 'Unauthenticated.'),
        ),
      );
    });

    test('a 422 validation response exposes fieldErrors', () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/listings/nearby'),
          response: Response(
            requestOptions: RequestOptions(path: '/listings/nearby'),
            statusCode: 422,
            data: {
              'message': 'The radius km field must be between 1 and 50.',
              'errors': {
                'radius_km': ['The radius km field must be between 1 and 50.'],
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        client.nearbyListings(latitude: 23.78, longitude: 90.27, radiusKm: 500),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isValidationError, 'isValidationError', isTrue)
              .having(
                (e) => e.fieldErrors?['radius_km'],
                'fieldErrors',
                isNotNull,
              ),
        ),
      );
    });
  });

  group('updateProfile', () {
    // Regression test: FormData has no real boolean type — Dio stringifies
    // a raw Dart bool to the literal word "true"/"false" (see
    // FormData.fromMap's `value?.toString()`), which fails Laravel's
    // `boolean` validation rule (it only accepts 1/0/"1"/"0"). That 422
    // silently rejected every real profile save regardless of any other
    // field, since show_handover_radius is always included. This pins the
    // fix: the wire value must be the string '1' or '0', never a bool.
    test(
      'sends show_handover_radius as the string "1"/"0", never a bool',
      () async {
        when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/auth/me'),
            statusCode: 200,
            data: {
              'data': {
                'id': 1,
                'name': 'Me',
                'email': 'me@example.com',
                'show_handover_radius': false,
                'is_suspended': false,
                'is_verified': false,
                'rating_avg': 0,
                'created_at': '2026-01-01T00:00:00Z',
              },
            },
          ),
        );

        await client.updateProfile(showHandoverRadius: false);

        final formData =
            verify(
                  () => dio.post(
                    '/auth/me',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as FormData;
        final field = formData.fields.firstWhere(
          (e) => e.key == 'show_handover_radius',
        );

        expect(field.value, isA<String>());
        expect(field.value, '0');
      },
    );

    test('sends true as "1"', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 200,
          data: {
            'data': {
              'id': 1,
              'name': 'Me',
              'email': 'me@example.com',
              'show_handover_radius': true,
              'is_suspended': false,
              'is_verified': false,
              'rating_avg': 0,
              'created_at': '2026-01-01T00:00:00Z',
            },
          },
        ),
      );

      await client.updateProfile(showHandoverRadius: true);

      final formData =
          verify(
                () => dio.post('/auth/me', data: captureAny(named: 'data')),
              ).captured.single
              as FormData;
      final field = formData.fields.firstWhere(
        (e) => e.key == 'show_handover_radius',
      );

      expect(field.value, '1');
    });
  });
}
