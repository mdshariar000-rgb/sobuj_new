/// Mirrors App\Enums\AiMessageRole on the backend.
enum AiMessageRole {
  user('user'),
  assistant('assistant');

  const AiMessageRole(this.value);

  final String value;

  static AiMessageRole fromValue(String value) {
    return AiMessageRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () =>
          throw FormatException('Unknown AiMessageRole value: $value'),
    );
  }
}
