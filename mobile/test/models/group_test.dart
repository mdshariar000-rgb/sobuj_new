import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';

Map<String, dynamic> _baseJson({bool? verified}) => {
  'id': 1,
  'name': 'Balcony Growers',
  'slug': 'balcony-growers',
  'visibility': 'public',
  'verified': ?verified,
  'created_at': '2026-01-01T00:00:00+00:00',
};

void main() {
  group('Group.fromJson', () {
    test('parses verified: true into isVerified', () {
      final group = Group.fromJson(_baseJson(verified: true));

      expect(group.isVerified, isTrue);
    });

    test('parses verified: false into isVerified', () {
      final group = Group.fromJson(_baseJson(verified: false));

      expect(group.isVerified, isFalse);
    });

    test('leaves isVerified null when the field is absent', () {
      final group = Group.fromJson(_baseJson());

      expect(group.isVerified, isNull);
    });
  });

  group('Group.copyWith', () {
    test('carries isVerified through unrelated updates', () {
      final group = Group.fromJson(_baseJson(verified: true));

      final updated = group.copyWith(membersCount: 42);

      expect(updated.isVerified, isTrue);
      expect(updated.membersCount, 42);
    });
  });
}
