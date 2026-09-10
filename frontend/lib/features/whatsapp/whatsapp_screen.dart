import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/providers.dart';
import '../../core/network/api_result.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'whatsapp_status_provider.dart';

/// Compact read-only version of the WhatsApp page's own status view, shown from [TopStatusBar]'s
/// WhatsApp chip — same reachable/connected/QR logic and the same 5s QR-refresh poll, just without
/// the logout/re-pair action (that stays a WhatsApp-page-only action).
class WhatsappStatusDialog extends ConsumerStatefulWidget {
  const WhatsappStatusDialog({super.key});

  @override
  ConsumerState<WhatsappStatusDialog> createState() => _WhatsappStatusDialogState();
}

class _WhatsappStatusDialogState extends ConsumerState<WhatsappStatusDialog> {
  Timer? _qrPollTimer;

  void _ensurePolling(bool shouldPoll) {
    final isPolling = _qrPollTimer?.isActive ?? false;
    if (shouldPoll && !isPolling) {
      _qrPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => ref.invalidate(whatsappStatusProvider));
    } else if (!shouldPoll && isPolling) {
      _qrPollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _qrPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(whatsappStatusProvider);

    return Dialog(
      child: SizedBox(
        width: 380,
        child: statusAsync.when(
          data: (s) {
            final reachable = s != null && s['baileysReachable'] == true;
            final connected = s != null && s['connected'] == true;
            final qr = s?['qr'] as String?;
            WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePolling(reachable && !connected));

            return WhatsappStatusCard(
              reachable: reachable,
              connected: connected,
              qr: qr,
              queuedCount: s?['queuedCount'] as int?,
              sentCount: s?['sentCount'] as int?,
              failedCount: s?['failedCount'] as int?,
              configuredUrl: s?['configuredUrl'] as String?,
              loggingOut: false,
              onLogout: () {},
              showActions: false,
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load WhatsApp status: $e')),
        ),
      ),
    );
  }
}

final _whatsappOutboxProvider = FutureProvider.autoDispose<List<dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<dynamic>>('/api/whatsapp/outbox', (json) => json as List<dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

Widget _outboxStatusPill(int status) => switch (status) {
      0 => StatusPill.draft('Queued'),
      1 => StatusPill.warning('Sending'),
      2 => StatusPill.success('Sent'),
      _ => StatusPill.error('Failed'),
    };

class WhatsappScreen extends ConsumerStatefulWidget {
  const WhatsappScreen({super.key});

  @override
  ConsumerState<WhatsappScreen> createState() => _WhatsappScreenState();
}

class _WhatsappScreenState extends ConsumerState<WhatsappScreen> {
  Timer? _qrPollTimer;
  bool _loggingOut = false;

  void _refresh() {
    ref.invalidate(whatsappStatusProvider);
    ref.invalidate(_whatsappOutboxProvider);
  }

  /// Baileys QR codes expire and rotate every ~20-30s, so a manual refresh button alone would mean
  /// the admin is usually staring at a dead code by the time they scan it - poll while unpaired.
  void _ensurePolling(bool shouldPoll) {
    final isPolling = _qrPollTimer?.isActive ?? false;
    if (shouldPoll && !isPolling) {
      _qrPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => ref.invalidate(whatsappStatusProvider));
    } else if (!shouldPoll && isPolling) {
      _qrPollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _qrPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/whatsapp/logout', (_) {});
    if (!mounted) return;
    setState(() => _loggingOut = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(whatsappStatusProvider);
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(whatsappStatusProvider);
    final outboxAsync = ref.watch(_whatsappOutboxProvider);

    return ListScreenShortcuts(
      onRefresh: _refresh,
      child: Scaffold(
        body: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh (F5)', onPressed: _refresh),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: statusAsync.when(
                data: (s) {
                  final reachable = s != null && s['baileysReachable'] == true;
                  final connected = s != null && s['connected'] == true;
                  final qr = s?['qr'] as String?;

                  // Only keep polling while there's an actual QR to watch expire - not while the
                  // bridge is simply unreachable (that would just hammer a dead service).
                  WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePolling(reachable && !connected));

                  return WhatsappStatusCard(
                    reachable: reachable,
                    connected: connected,
                    qr: qr,
                    queuedCount: s?['queuedCount'] as int?,
                    sentCount: s?['sentCount'] as int?,
                    failedCount: s?['failedCount'] as int?,
                    configuredUrl: s?['configuredUrl'] as String?,
                    loggingOut: _loggingOut,
                    onLogout: _logout,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed: $e'),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _TestMessageCard()),
            const SizedBox(height: 16),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Outbox', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: outboxAsync.when(
                  data: (items) {
                    final rows = items ?? const [];
                    return AppListCard(
                      emptyMessage: items == null ? 'Could not load outbox.' : 'Nothing sent yet.',
                      emptyIcon: Icons.outbox_outlined,
                      columns: const [
                        AppListColumn('Recipient', flex: 2),
                        AppListColumn('Status', flex: 3),
                      ],
                      itemCount: rows.length,
                      cellsBuilder: (context, i) {
                        final it = rows[i] as Map<String, dynamic>;
                        final status = it['status'] as int;
                        final lastError = it['lastError'] as String?;
                        return [
                          Text(it['recipientNumber'] as String, style: const TextStyle(fontSize: 13)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _outboxStatusPill(status),
                              if (lastError != null) ...[
                                const SizedBox(width: 8),
                                Flexible(child: Text(lastError, style: const TextStyle(color: AppPalette.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis)),
                              ],
                            ],
                          ),
                        ];
                      },
                    );
                  },
                  loading: () => Card(child: SkeletonTableRows(columns: 2)),
                  error: (e, _) => Center(child: Text('Failed to load outbox: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets an admin confirm the bridge actually delivers before relying on it for real documents —
/// hits /api/whatsapp/test-send directly (no outbox row, not tied to any document).
class _TestMessageCard extends ConsumerStatefulWidget {
  const _TestMessageCard();

  @override
  ConsumerState<_TestMessageCard> createState() => _TestMessageCardState();
}

class _TestMessageCardState extends ConsumerState<_TestMessageCard> {
  final _number = TextEditingController();
  final _message = TextEditingController(text: 'This is a test message from the Biz system.');
  bool _sending = false;
  String? _result;
  bool _resultSuccess = false;

  Future<void> _send() async {
    if (_number.text.trim().isEmpty || _message.text.trim().isEmpty) return;

    setState(() {
      _sending = true;
      _result = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/whatsapp/test-send',
      (json) => json as Map<String, dynamic>,
      body: {'recipientNumber': _number.text.trim(), 'message': _message.text.trim()},
    );

    if (!mounted) return;
    setState(() => _sending = false);

    switch (result) {
      case ApiSuccess(data: final data):
        setState(() {
          _resultSuccess = data['success'] == true;
          _result = _resultSuccess ? 'Sent successfully.' : 'Failed: ${data['error']}';
        });
      case ApiFailure(message: final msg):
        setState(() {
          _resultSuccess = false;
          _result = msg;
        });
      case ApiNetworkError(message: final msg):
        setState(() {
          _resultSuccess = false;
          _result = 'Could not reach the Host: $msg';
        });
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send Test Message', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Confirm the bridge can actually deliver before relying on it for real documents.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _number,
                    decoration: const InputDecoration(labelText: 'Number', hintText: '98XXXXXXXX', isDense: true, counterText: ''),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _message,
                    decoration: const InputDecoration(labelText: 'Message', isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send'),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              Text(_result!, style: TextStyle(color: _resultSuccess ? Colors.green.shade700 : Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Public so [TopStatusBar]'s WhatsApp chip can pop the same status/QR view in a dialog instead of
/// only being visible on the WhatsApp page itself.
class WhatsappStatusCard extends StatelessWidget {
  final bool reachable;
  final bool connected;
  final String? qr;
  final int? queuedCount;
  final int? sentCount;
  final int? failedCount;
  final String? configuredUrl;
  final bool loggingOut;
  final VoidCallback onLogout;

  /// False in the compact dialog view — logout/re-pair stays a WhatsApp-page-only action there.
  final bool showActions;

  const WhatsappStatusCard({
    super.key,
    required this.reachable,
    required this.connected,
    required this.qr,
    required this.queuedCount,
    required this.sentCount,
    required this.failedCount,
    required this.configuredUrl,
    required this.loggingOut,
    required this.onLogout,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!reachable) {
      // No configured URL at all vs. configured-but-unreachable are different problems for the
      // Shop Admin to act on - the latter is very often a port conflict (something else already
      // listening on the configured port when the bridge tried to start), so call that out
      // explicitly rather than leaving them to guess.
      final message = configuredUrl == null
          ? 'WhatsApp bridge URL could not be resolved on this Host. Make sure the "ERP WhatsApp '
              'Bridge" Windows service is installed and has run at least once - it writes its port to '
              'resolved-port.txt automatically, which the Host reads on startup. Restarting the ErpHost '
              'service after installing/reinstalling the bridge will pick this up.'
          : 'Could not reach the WhatsApp bridge at $configuredUrl. It may not be running, or another '
              'program may already be using that port - check the "ERP WhatsApp Bridge" Windows service, '
              'and if it won\'t start, that\'s almost always a port conflict.';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.circle, color: Colors.red, size: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
    }

    if (!connected) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.circle, color: Colors.orange, size: 14),
                  SizedBox(width: 8),
                  Text('Not paired yet'),
                ],
              ),
              const SizedBox(height: 16),
              if (qr != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: QrImageView(data: qr!, size: 220, backgroundColor: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'On the shop\'s WhatsApp phone: Settings > Linked Devices > Link a Device, then scan this code.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'This code refreshes automatically every few seconds.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(height: 12),
                      Text('Waiting for a pairing code from the bridge service...'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 14),
                const SizedBox(width: 8),
                const Text('Connected'),
                const SizedBox(width: 24),
                Text('Queued: $queuedCount'),
                const SizedBox(width: 12),
                Text('Sent: $sentCount'),
                const SizedBox(width: 12),
                Text('Failed: $failedCount'),
              ],
            ),
            if (showActions)
              TextButton.icon(
                onPressed: loggingOut ? null : onLogout,
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Unlink / Re-pair'),
              ),
          ],
        ),
      ),
    );
  }
}
