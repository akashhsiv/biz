/// Set at build time: `flutter build windows --dart-define=APP_VARIANT=host` (or `slave`).
/// Purely cosmetic — window title, icon, and the connection screen's default URL prefill.
/// Every actual feature/screen is gated by the logged-in user's permissions, not this flag.
class AppVariant {
  static const String value = String.fromEnvironment(
    'APP_VARIANT',
    defaultValue: 'slave',
  );

  static bool get isHost => value == 'host';

  static String get appTitle => isHost ? 'ERP Host' : 'ERP Slave';

  /// Host builds default to localhost since the Shop Admin usually runs it on the Host PC itself.
  static String get defaultHostUrlPrefill => isHost ? 'localhost:5000' : '';
}
