import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/storage/app_storage.dart';
import 'connection_state.dart';

/// Owns the Slave's "can we reach the Host" state, polled periodically so a mid-session drop is
/// visible everywhere in the app, not just discovered when the user next taps something —
/// ARCHITECTURE.md §7-9.
class ConnectionController extends StateNotifier<ConnectionInfo> {
  final ApiClient _api;
  final AppStorage _storage;
  Timer? _pollTimer;
  Timer? _quickRecheckTimer;
  int _consecutiveFailures = 0;

  ConnectionController(this._api, this._storage) : super(ConnectionInfo.initial) {
    _init();
  }

  Future<void> _init() async {
    final savedUrl = await _storage.getHostUrl();
    if (savedUrl == null || savedUrl.isEmpty) {
      state = const ConnectionInfo(status: ConnectionStatus.disconnected);
      return;
    }

    _api.setBaseUrl(savedUrl);
    await checkHealth();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => checkHealth());
  }

  Future<bool> checkHealth() async {
    if (_api.baseUrl == null) {
      state = const ConnectionInfo(status: ConnectionStatus.disconnected);
      return false;
    }

    final everConnected = state.hasEverConnected;
    // Only show the "checking" transition (which briefly hides the last-known status) on a first
    // connect attempt — once we've connected before, a routine 20s poll shouldn't visibly flicker
    // the UI while it's in flight.
    if (!everConnected) {
      state = ConnectionInfo(status: ConnectionStatus.checking, hostUrl: _api.baseUrl, hasEverConnected: everConnected);
    }

    final result = await _api.get<Map<String, dynamic>>('/api/health', (json) => json as Map<String, dynamic>);

    switch (result) {
      case ApiSuccess():
        _consecutiveFailures = 0;
        _quickRecheckTimer?.cancel();
        state = ConnectionInfo(status: ConnectionStatus.connected, hostUrl: _api.baseUrl, hasEverConnected: true);
        return true;
      case ApiFailure(message: final msg):
        _handleFailure(msg, everConnected);
        return false;
      case ApiNetworkError(message: final msg):
        _handleFailure(msg, everConnected);
        return false;
    }
  }

  /// A single failed poll after a previously-successful connection is usually a one-off blip (a
  /// slow DB round-trip, a momentary hiccup) — not a real outage. Only flip to the disconnected
  /// state (which shows the red banner) after a second consecutive failure shortly after, so a
  /// transient blip doesn't flash the banner for no reason.
  void _handleFailure(String msg, bool everConnected) {
    _consecutiveFailures++;

    if (!everConnected || _consecutiveFailures >= 2) {
      state = ConnectionInfo(status: ConnectionStatus.disconnected, hostUrl: _api.baseUrl, error: msg, hasEverConnected: everConnected);
      return;
    }

    _quickRecheckTimer?.cancel();
    _quickRecheckTimer = Timer(const Duration(seconds: 5), checkHealth);
  }

  /// User entered/changed the Host URL from the connection dialog. A single retry after a short
  /// pause absorbs the common "right IP, first attempt times out" case — a cold ARP cache entry or
  /// the Host still finishing startup — rather than surfacing that as a real failure to the user.
  Future<bool> connectTo(String url) async {
    await _storage.saveHostUrl(url);
    _api.setBaseUrl(url);
    var ok = await checkHealth();
    if (!ok) {
      await Future<void>.delayed(const Duration(seconds: 2));
      ok = await checkHealth();
    }
    if (ok) _startPolling();
    return ok;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _quickRecheckTimer?.cancel();
    super.dispose();
  }
}

final connectionControllerProvider = StateNotifierProvider<ConnectionController, ConnectionInfo>((ref) {
  return ConnectionController(ref.watch(apiClientProvider), ref.watch(appStorageProvider));
});
