/// Mirrors App\Enums\TransactionType on the backend.
enum TransactionType {
  swap('swap', 'Trade'),
  free('free', 'Free'),
  sell('sell', 'For Sale'),
  swapOrCash('swap_or_cash', 'Swap or Cash'),

  /// A "wanted" listing — the poster is looking to acquire something, not
  /// offering it (no photos; `price`, when set, is a budget ceiling).
  wanted('wanted', 'Looking to Buy');

  const TransactionType(this.value, this.label);

  final String value;
  final String label;

  bool get isRequest => this == TransactionType.wanted;

  static TransactionType fromValue(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () =>
          throw FormatException('Unknown TransactionType value: $value'),
    );
  }
}

/// Mirrors App\Enums\ListingCondition on the backend.
enum ListingCondition {
  newFresh('new_fresh', 'New / Fresh'),
  establishedPotted('established_potted', 'Established / Potted'),
  lightlyUsed('lightly_used', 'Lightly Used'),
  organicCertified('organic_certified', 'Organic Certified');

  const ListingCondition(this.value, this.label);

  final String value;
  final String label;

  static ListingCondition fromValue(String value) {
    return ListingCondition.values.firstWhere(
      (condition) => condition.value == value,
      orElse: () =>
          throw FormatException('Unknown ListingCondition value: $value'),
    );
  }
}

/// Mirrors App\Enums\ListingStatus on the backend.
enum ListingStatus {
  active('active', 'Active'),
  reserved('reserved', 'Reserved'),
  completed('completed', 'Completed'),
  deleted('deleted', 'Deleted');

  const ListingStatus(this.value, this.label);

  final String value;
  final String label;

  static ListingStatus fromValue(String value) {
    return ListingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () =>
          throw FormatException('Unknown ListingStatus value: $value'),
    );
  }
}

/// Mirrors App\Enums\ExperienceLevel on the backend.
enum ExperienceLevel {
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate'),
  experienced('experienced', 'Experienced'),
  expert('expert', 'Expert');

  const ExperienceLevel(this.value, this.label);

  final String value;
  final String label;

  static ExperienceLevel fromValue(String value) {
    return ExperienceLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () =>
          throw FormatException('Unknown ExperienceLevel value: $value'),
    );
  }
}

/// Mirrors App\Enums\GrowingSetup on the backend.
enum GrowingSetup {
  balcony('balcony', 'Balcony'),
  indoor('indoor', 'Indoor'),
  backyard('backyard', 'Backyard'),
  rooftop('rooftop', 'Rooftop'),
  communityGarden('community_garden', 'Community Garden'),
  greenhouse('greenhouse', 'Greenhouse');

  const GrowingSetup(this.value, this.label);

  final String value;
  final String label;

  static GrowingSetup fromValue(String value) {
    return GrowingSetup.values.firstWhere(
      (setup) => setup.value == value,
      orElse: () => throw FormatException('Unknown GrowingSetup value: $value'),
    );
  }
}
