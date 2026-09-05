import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_variant.dart';
import '../../shared/widgets/app_toast.dart';
import 'connection_controller.dart';
import 'connection_state.dart';

/// Must match HostDiscoveryBroadcastService.DiscoveryPort on the Host.
const _discoveryPort = 45678;

/// Listens briefly for the Host's UDP broadcast announcement so a Slave PC can find it without the
/// admin typing an IP address. The Host's address is read from the packet's sender, not its
/// payload - the payload only carries the port and a friendly name for display. Returns null (never
/// throws) if nothing is heard in time, or the platform/network doesn't allow broadcast listening
/// (e.g. AP-isolated Wi-Fi, or a firewall prompt was denied) - manual entry is always the fallback.
Future<String?> _discoverHost({Duration timeout = const Duration(seconds: 2)}) async {
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort, reuseAddress: true);
    final completer = Completer<String?>();

    socket.listen((event) {
      if (event != RawSocketEvent.read || completer.isCompleted) return;
      final datagram = socket!.receive();
      if (datagram == null) return;
      try {
        final payload = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (payload['type'] == 'ERP_HOST') {
          completer.complete('${datagram.address.address}:${payload['port']}');
        }
      } catch (_) {
        // Not our packet (or malformed) - keep listening for the timeout window.
      }
    });

    return await completer.future.timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  } finally {
    socket?.close();
  }
}

/// Shown whenever the app cannot confirm the Host is reachable. The app never lets the user past
/// this screen while disconnected — see ARCHITECTURE.md §7.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _controller = TextEditingController(text: AppVariant.defaultHostUrlPrefill);
  bool _connecting = false;
  bool _restarting = false;

  /// A last-resort escape hatch for whatever a plain retry can't fix (a wedged network stack, a
  /// stuck Dio connection pool after the Host bounced) — relaunches a fresh copy of this same .exe
  /// and exits the current process, rather than trying to reset in-memory state piecemeal.
  Future<void> _hardRestart() async {
    setState(() => _restarting = true);
    try {
      await Process.start(Platform.resolvedExecutable, [], mode: ProcessStartMode.detached, runInShell: true);
    } catch (_) {
      // Even if relaunching failed, exiting still lets the admin reopen the app manually -
      // better than sitting on a dead "Restarting…" state forever.
    }
    exit(0);
  }

  @override
  void initState() {
    super.initState();
    final saved = ref.read(connectionControllerProvider).hostUrl;
    if (saved != null) {
      _controller.text = saved.replaceFirst('http://', '');
    } else {
      // First run on this PC, nothing saved yet - try to find the Host automatically before
      // making the admin type anything. Silent (no error toast) since this is speculative.
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect(silent: true));
    }
  }

  Future<void> _connect() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    await _attemptConnect(url);
  }

  /// Tries the addresses most likely to work without the user typing anything: the field's
  /// current value first (in case they already have the right one, or a saved one restored it),
  /// then — for the Host variant only, since that's the one bundled with the Host's own client and
  /// always talks to a backend on the very same PC — localhost:5000, the Host's fixed API port.
  /// A Slave build has no such guess to make; it always needs a real network address from the admin.
  Future<void> _autoConnect({bool silent = false}) async {
    if (!mounted) return;
    setState(() => _connecting = true);
    final discovered = await _discoverHost();
    if (mounted) setState(() => _connecting = false);

    final candidates = <String>{
      ?discovered,
      if (_controller.text.trim().isNotEmpty) _controller.text.trim(),
      if (AppVariant.isHost) 'localhost:5000',
    };

    for (final candidate in candidates) {
      if (!mounted) return;
      _controller.text = candidate;
      final ok = await _attemptConnect(candidate, showErrorOnFailure: false);
      if (ok) return;
    }

    // The initState-triggered first-run attempt is speculative (nothing saved yet, nothing typed) -
    // an error toast there would just be noise before the admin has done anything at all.
    if (mounted && !silent) {
      final error = ref.read(connectionControllerProvider).error;
      AppToast.error(error ?? 'Could not reach the Host automatically. Enter its address manually below.');
    }
  }

  Future<bool> _attemptConnect(String url, {bool showErrorOnFailure = true}) async {
    if (!mounted) return false;
    setState(() => _connecting = true);
    final ok = await ref.read(connectionControllerProvider.notifier).connectTo(url);
    if (mounted) setState(() => _connecting = false);

    if (!ok && showErrorOnFailure && mounted) {
      final error = ref.read(connectionControllerProvider).error;
      AppToast.error(error ?? 'Could not reach that address.');
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionControllerProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lan_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  AppVariant.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  connection.status == ConnectionStatus.checking ? 'Connecting…' : 'Host Connection Required',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (connection.status != ConnectionStatus.checking) ...[
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Host address',
                      hintText: '192.168.1.100:5000',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _connecting ? null : _connect,
                    child: _connecting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Connect'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _connecting ? null : _autoConnect,
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('Auto-Connect'),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _restarting ? null : _hardRestart,
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    icon: _restarting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.restart_alt, size: 18),
                    label: Text(_restarting ? 'Restarting…' : 'Nothing working? Restart the app'),
                  ),
                  const SizedBox(height: 24),
                  _TipsCard(),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tips', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _Tip('Ask your admin for the address shown on the Host\'s dashboard.'),
            _Tip('Make sure this PC is on the same Wi-Fi/network as the Host.'),
            _Tip('Format: 192.168.1.100:5000 (IP address, then the port).'),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
