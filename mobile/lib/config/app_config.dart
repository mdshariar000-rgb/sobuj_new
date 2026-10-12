/// Build-time configuration. Override with `--dart-define`, e.g.:
///   flutter run --dart-define=API_BASE_URL=https://staging.example.com/api/v1
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://codecell.site/api/v1',
  );

  /// The public website the API lives on — share links point here.
  static String get webBaseUrl =>
      apiBaseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');

  /// The page behind a listing's Share button: a preview plus links to get
  /// the app (see SharePageController on the backend).
  static String listingShareUrl(int listingId) => '$webBaseUrl/l/$listingId';

  /// The page behind a profile's Share button.
  static String profileShareUrl(int userId) => '$webBaseUrl/u/$userId';

  /// The Reverb app key used by the chat thread's live WebSocket connection —
  /// a public identifier (not a secret), the same one already embedded in
  /// the web build via Vite's VITE_REVERB_APP_KEY.
  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: 'e9e4402af65fe95d2a4bdb27c9ccf811',
  );

  /// Default search radius shown when the Discovery screen first loads —
  /// wide enough to actually surface real nearby listings (production data
  /// showed every active listing sitting 13-15km out from a typical user's
  /// location; a tighter default would show an empty feed by default).
  static const double defaultRadiusKm = 25;

  static const double minRadiusKm = 1;
  static const double maxRadiusKm = 50;
}
