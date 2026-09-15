/// Mirrors App\Enums\EventFormat on the backend.
enum EventFormat {
  inPerson('in_person', 'In Person'),
  online('online', 'Online'),
  hybrid('hybrid', 'Hybrid');

  const EventFormat(this.value, this.label);

  final String value;
  final String label;

  static EventFormat fromValue(String value) {
    return EventFormat.values.firstWhere(
      (format) => format.value == value,
      orElse: () => throw FormatException('Unknown EventFormat value: $value'),
    );
  }
}

/// Mirrors App\Enums\EventStatus on the backend.
enum EventStatus {
  draft('draft', 'Draft'),
  published('published', 'Published'),
  canceled('canceled', 'Canceled');

  const EventStatus(this.value, this.label);

  final String value;
  final String label;

  static EventStatus fromValue(String value) {
    return EventStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw FormatException('Unknown EventStatus value: $value'),
    );
  }
}

/// Mirrors App\Enums\EventAttendeeStatus on the backend.
enum EventAttendeeStatus {
  going('going', 'Going'),
  interested('interested', 'Interested');

  const EventAttendeeStatus(this.value, this.label);

  final String value;
  final String label;

  static EventAttendeeStatus fromValue(String value) {
    return EventAttendeeStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () =>
          throw FormatException('Unknown EventAttendeeStatus value: $value'),
    );
  }
}
