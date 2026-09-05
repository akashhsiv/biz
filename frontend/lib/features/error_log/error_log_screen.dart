import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/file_logger.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_toast.dart';

/// Shows two logs: this client's own plain-text log (see FileLogger — crashes and handled API
/// failures on this PC), and the Host's server-side log (see ExceptionHandlingMiddleware — unhandled
/// 500s on the backend, previously invisible since a Windows Service has nowhere to print console
/// output). Between the two, every "it broke once and nobody knows why" case should be diagnosable
/// without a debugger ever being attached.
class ErrorLogScreen extends StatelessWidget {
  const ErrorLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: Column(
          children: [
            Container(
              color: AppPalette.card,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppPalette.primary,
                unselectedLabelColor: AppPalette.textSecondary,
                indicatorColor: AppPalette.primary,
                tabs: [Tab(text: 'This Client'), Tab(text: 'Host Server')],
              ),
            ),
            const Expanded(child: TabBarView(children: [_ClientLogTab(), _ServerLogTab()])),
          ],
        ),
      ),
    );
  }
}

class _ClientLogTab extends StatefulWidget {
  const _ClientLogTab();

  @override
  State<_ClientLogTab> createState() => _ClientLogTabState();
}

class _ClientLogTabState extends State<_ClientLogTab> {
  String _content = '';
  String _path = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final content = await FileLogger.read();
    final path = await FileLogger.filePath();
    if (!mounted) return;
    setState(() {
      _content = content;
      _path = path;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Error Log'),
        content: const Text('This permanently deletes the log file\'s contents. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    await FileLogger.clear();
    await _load();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (mounted) AppToast.success('Copied to clipboard.');
  }

  Future<void> _openFolder() async {
    await Process.start('explorer.exe', ['/select,', _path]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: Text('File: $_path', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey))),
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
              IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'Copy to clipboard', onPressed: _content.isEmpty ? null : _copy),
              IconButton(icon: const Icon(Icons.folder_open_outlined), tooltip: 'Show file in Explorer', onPressed: _openFolder),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear log', onPressed: _content.isEmpty ? null : _clear),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _content.isEmpty
                  ? const Center(child: Text('No errors logged. This app has not crashed or hit an uncaught error.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(_content, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    ),
        ),
      ],
    );
  }
}

class _ServerLogTab extends ConsumerStatefulWidget {
  const _ServerLogTab();

  @override
  ConsumerState<_ServerLogTab> createState() => _ServerLogTabState();
}

class _ServerLogTabState extends ConsumerState<_ServerLogTab> {
  String _content = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.get<String>('/api/diagnostics/server-log', (json) => json as String);
    if (!mounted) return;

    switch (result) {
      case ApiSuccess(data: final data):
        setState(() {
          _content = data;
          _loading = false;
        });
      case ApiFailure(message: final msg):
        setState(() {
          _error = msg;
          _loading = false;
        });
      case ApiNetworkError(message: final msg):
        setState(() {
          _error = 'Could not reach the Host: $msg';
          _loading = false;
        });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Server Log'),
        content: const Text('This permanently deletes the Host\'s server-side log file. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = ref.read(apiClientProvider);
    await api.delete<void>('/api/diagnostics/server-log', (_) {});
    await _load();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (mounted) AppToast.success('Copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Every unhandled server error, from any client on the network.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
              IconButton(icon: const Icon(Icons.copy_outlined), tooltip: 'Copy to clipboard', onPressed: _content.isEmpty ? null : _copy),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear log', onPressed: _content.isEmpty ? null : _clear),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
                  : _content.isEmpty
                      ? const Center(child: Text('No server errors logged.'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(_content, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ),
        ),
      ],
    );
  }
}
