import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connection/connection_controller.dart';
import '../../features/connection/connection_state.dart';

/// Persistent, app-wide indicator — a disconnect mid-task should be visible immediately, not
/// discovered only when the next action fails (ARCHITECTURE.md §9). Colors match the Figma
/// source's ConnBanner exactly (amber, not a hard red/orange alert) — a degraded/reconnecting
/// Host is treated as a caution, not a hard failure.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  static const _bg = Color(0xFFFEF3C7);
  static const _border = Color(0xFFFDE68A);
  static const _text = Color(0xFF92400E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionControllerProvider);
    if (connection.status == ConnectionStatus.connected) return const SizedBox.shrink();

    final isChecking = connection.status == ConnectionStatus.checking;

    return Material(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(isChecking ? Icons.sync : Icons.warning_amber_rounded, color: _text, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isChecking
                      ? 'Reconnecting to Host…'
                      : 'Connection to local server is degraded — some actions may be unavailable.',
                  style: const TextStyle(color: _text, fontSize: 12),
                ),
              ),
              if (!isChecking)
                TextButton(
                  onPressed: () => ref.read(connectionControllerProvider.notifier).checkHealth(),
                  style: TextButton.styleFrom(foregroundColor: _text),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
