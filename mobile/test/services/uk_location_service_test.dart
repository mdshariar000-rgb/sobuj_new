import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shobuj_mobile/services/uk_location_service.dart';

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(String path, Object data) => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: 200,
  data: data,
);

void main() {
  late MockDio dio;
  late UkLocationService service;

  setUp(() {
    dio = MockDio();
    service = UkLocationService(dio);
  });

  test('ignores queries shorter than two characters', () async {
    expect(await service.search(' a '), isEmpty);
    verifyNever(() => dio.get(any()));
  });

  test('a place name searches places and labels each with its area', () async {
    when(
      () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer(
      (_) async => _ok('/places', {
        'status': 200,
        'result': [
          {
            'name_1': 'Headingley',
            'district_borough': 'Leeds',
            'county_unitary': null,
            'country': 'England',
            'latitude': 53.8173,
            'longitude': -1.5776,
          },
          {
            'name_1': 'Manchester',
            'district_borough': 'Manchester',
            'county_unitary': null,
            'country': 'England',
            'latitude': 53.4794,
            'longitude': -2.2453,
          },
        ],
      }),
    );

    final results = await service.search('head');

    verify(
      () => dio.get(
        'https://api.postcodes.io/places',
        queryParameters: {'q': 'head', 'limit': 10},
      ),
    ).called(1);
    expect(results.map((r) => r.label), [
      'Headingley, Leeds, England',
      'Manchester, England',
    ]);
    expect(results.first.latitude, 53.8173);
  });

  test('a full postcode looks up that postcode', () async {
    when(() => dio.get(any())).thenAnswer(
      (_) async => _ok('/postcodes', {
        'status': 200,
        'result': {
          'postcode': 'LS6 3AA',
          'admin_ward': 'Headingley & Hyde Park',
          'admin_district': 'Leeds',
          'country': 'England',
          'latitude': 53.820293,
          'longitude': -1.577005,
        },
      }),
    );

    final results = await service.search('ls6 3aa');

    verify(
      () => dio.get('https://api.postcodes.io/postcodes/ls6%203aa'),
    ).called(1);
    expect(
      results.single.label,
      'LS6 3AA, Headingley & Hyde Park, Leeds, England',
    );
  });

  test('a postcode district looks up the outcode', () async {
    when(() => dio.get(any())).thenAnswer(
      (_) async => _ok('/outcodes', {
        'status': 200,
        'result': {
          'outcode': 'LS6',
          'admin_district': ['Leeds'],
          'country': ['England'],
          'latitude': 53.8201,
          'longitude': -1.5708,
        },
      }),
    );

    final results = await service.search('LS6');

    verify(() => dio.get('https://api.postcodes.io/outcodes/LS6')).called(1);
    expect(results.single.label, 'LS6, Leeds, England');
  });

  test(
    'an unknown postcode (404) returns no results instead of throwing',
    () async {
      final options = RequestOptions(path: '/postcodes');
      when(() => dio.get(any())).thenThrow(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 404),
        ),
      );

      expect(await service.search('ZZ9 9ZZ'), isEmpty);
    },
  );

  test(
    'a network failure is rethrown so the field can show an error',
    () async {
      when(
        () => dio.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/places'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(service.search('leeds'), throwsA(isA<DioException>()));
    },
  );
}
