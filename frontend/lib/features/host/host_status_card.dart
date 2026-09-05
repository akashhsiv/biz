import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'host_status_provider.dart';

class HostStatusCard extends ConsumerWidget {
  const HostStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(hostStatusProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns_outlined),
                const SizedBox(width: 8),
                Text('Host Status', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.invalidate(hostStatusProvider),
                ),
              ],
            ),
            const Divider(),
            status.when(
              data: (s) {
                if (s == null) {
                  return const Text('Could not load Host status.');
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(context, 'Server', s.serverRunning, s.serverRunning ? 'Running' : 'Down'),
                    _row(context, 'Database', s.databaseConnected, s.databaseConnected ? 'Connected' : 'Disconnected'),
                    const SizedBox(height: 8),
                    if (s.connectionUrl != null)
                      Row(
                        children: [
                          const Text('Connection URL: '),
                          Expanded(child: SelectableText(s.connectionUrl!)),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'Copy',
                            onPressed: () => Clipboard.setData(ClipboardData(text: s.connectionUrl!)),
                          ),
                        ],
                      ),
                    Text('Connected Slaves: ${s.connectedSlaveCount}'),
                    const SizedBox(height: 8),
                    Text(s.lastBackupAt == null
                        ? 'Last Backup: never'
                        : 'Last Backup: ${s.lastBackupAt!.toLocal()} (${s.lastBackupStatus == 0 ? "success" : "failed"})'),
                    Text('WhatsApp Outbox: ${s.whatsappQueuedCount} queued, ${s.whatsappFailedCount} failed'),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Failed to load: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, bool ok, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text('$label: '),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
