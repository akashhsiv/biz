enum ConnectionStatus { checking, connected, disconnected }

class ConnectionInfo {
  final ConnectionStatus status;
  final String? hostUrl;
  final String? error;

  /// True once a health check has ever succeeded this app run. Distinguishes the *first* check
  /// (still `checking`, should show the connection screen) from a periodic recheck of an
  /// already-working session (also briefly `checking`, but should NOT boot the user back to the
  /// connection screen and tear down whatever screen/tab they're on - see ConnectivityBanner,
  /// which already shows a small "Reconnecting..." indicator for exactly this case).
  final bool hasEverConnected;

  const ConnectionInfo({required this.status, this.hostUrl, this.error, this.hasEverConnected = false});

  static const initial = ConnectionInfo(status: ConnectionStatus.checking);
}
