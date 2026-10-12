import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';

void main() {
  group('AppUser.fromJson', () {
    test('parses a full "self" response (from /auth/me or register/login)', () {
      final json = {
        'id': 3,
        'name': 'Search Test',
        'email': 'searchtest@example.com',
        'is_suspended': false,
        'suspension_reason': null,
        'is_verified': false,
        'experience_level': 'experienced',
        'growing_setup': 'balcony',
        'rating_avg': 4.5,
        'location': {'latitude': 23.78, 'longitude': 90.27},
        'created_at': '2026-01-01T00:00:00+00:00',
      };

      final user = AppUser.fromJson(json);

      expect(user.id, 3);
      expect(user.email, 'searchtest@example.com');
      expect(user.isSuspended, isFalse);
      expect(user.isVerified, isFalse);
      expect(user.experienceLevel, ExperienceLevel.experienced);
      expect(user.growingSetup, GrowingSetup.balcony);
      expect(user.ratingAvg, 4.5);
    });

    test(
      'parses a public (non-self) response with moderation fields absent',
      () {
        final json = {
          'id': 5,
          'name': 'Rina',
          'rating_avg': 4.5,
          'location': {'latitude': 23.78, 'longitude': 90.27},
          'created_at': '2026-01-01T00:00:00+00:00',
        };

        final user = AppUser.fromJson(json);

        expect(user.email, isNull);
        expect(user.isSuspended, isNull);
        expect(user.suspensionReason, isNull);
        expect(user.isVerified, isNull);
        expect(user.experienceLevel, isNull);
        expect(user.growingSetup, isNull);
      },
    );

    test('parses follow-graph fields when present (GET /users/{id})', () {
      final json = {
        'id': 9,
        'name': 'Karim',
        'rating_avg': 4.0,
        'followers_count': 12,
        'following_count': 3,
        'is_following': true,
        'created_at': '2026-01-01T00:00:00+00:00',
      };

      final user = AppUser.fromJson(json);

      expect(user.followersCount, 12);
      expect(user.followingCount, 3);
      expect(user.isFollowing, isTrue);
    });

    test('leaves follow-graph fields null when absent', () {
      final json = {
        'id': 9,
        'name': 'Karim',
        'rating_avg': 4.0,
        'created_at': '2026-01-01T00:00:00+00:00',
      };

      final user = AppUser.fromJson(json);

      expect(user.followersCount, isNull);
      expect(user.followingCount, isNull);
      expect(user.isFollowing, isNull);
    });
  });

  group('AppUser.copyWith', () {
    test('toggles isFollowing and updates followersCount', () {
      final user = AppUser(
        id: 1,
        name: 'Rina',
        ratingAvg: 0,
        followersCount: 4,
        isFollowing: false,
        createdAt: DateTime(2026, 1, 1),
      );

      final followed = user.copyWith(isFollowing: true, followersCount: 5);

      expect(followed.isFollowing, isTrue);
      expect(followed.followersCount, 5);
      // Unrelated fields are preserved.
      expect(followed.name, 'Rina');
    });
  });
}
