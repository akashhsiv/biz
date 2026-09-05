import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Fetches a document's PDF from the backend (the only place that ever generates one — ARCHITECTURE.md
/// §35). "View" and "Print" both go through the `printing` package's bundled PDF renderer/printer
/// instead of shelling out to the OS (`explorer.exe` / the shell's Print verb) — the shop PC has no
/// internet and often no PDF reader installed at all, so relying on a registered file association or
/// print handler silently failed (View fell back to opening the Documents folder; Print did nothing).
///
/// The fetch itself retries once automatically on a network error (a dropped Wi-Fi packet or a
/// mid-transfer blip shouldn't need the user to notice and re-click), shows a "still generating"
/// hint once it's taken a few seconds (first PDF after the Host starts cold-launches Chromium, which
/// can take a while), and surfaces a manual Retry action distinct from a plain toast when both
/// attempts fail — so a real problem (Host down) reads differently from "just try again."
class PdfButton extends ConsumerStatefulWidget {
  final String path;
  final String fileName;

  const PdfButton({super.key, required this.path, required this.fileName});

  @override
  ConsumerState<PdfButton> createState() => _PdfButtonState();
}

enum _FetchIntent { view, print }

class _PdfButtonState extends ConsumerState<PdfButton> {
  bool _loading = false;
  bool _slow = false;
  String? _error;
  _FetchIntent? _pendingIntent;

  Future<Uint8List?> _fetchOnce() async {
    final api = ref.read(apiClientProvider);
    final result = await api.getBytes(widget.path);
    return switch (result) {
      ApiSuccess(data: final bytes) => Uint8List.fromList(bytes),
      ApiFailure(message: final msg) => Future.error('Could not generate PDF: $msg'),
      ApiNetworkError(message: final msg) => Future.error('Could not reach the Host: $msg'),
    };
  }

  Future<Uint8List?> _fetch(_FetchIntent intent) async {
    setState(() {
      _loading = true;
      _slow = false;
      _error = null;
      _pendingIntent = intent;
    });

    final slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slow = true);
    });

    try {
      return await _fetchOnce();
    } catch (_) {
      // One silent retry - most failures here are a transient network blip or the Host just having
      // finished cold-starting Chromium, not a real problem worth bothering the user about.
      try {
        return await _fetchOnce();
      } catch (e) {
        if (!mounted) return null;
        setState(() => _error = e.toString());
        return null;
      }
    } finally {
      slowTimer.cancel();
      if (mounted) {
        setState(() {
          _loading = false;
          _slow = false;
          _pendingIntent = null;
        });
      }
    }
  }

  Future<void> _view() async {
    final bytes = await _fetch(_FetchIntent.view);
    if (bytes == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PdfViewerScreen(fileName: widget.fileName, bytes: bytes),
    ));
  }

  Future<void> _print() async {
    final bytes = await _fetch(_FetchIntent.print);
    if (bytes == null) return;
    await Printing.layoutPdf(name: widget.fileName, onLayout: (_) async => bytes);
  }

  void _retry() {
    final intent = _pendingIntent;
    setState(() => _error = null);
    if (intent == _FetchIntent.print) {
      _print();
    } else {
      _view();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(_error!, style: const TextStyle(color: AppPalette.error, fontSize: 12), overflow: TextOverflow.ellipsis)),
          TextButton(onPressed: _retry, child: const Text('Retry')),
        ],
      );
    }

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            if (_slow) ...[
              const SizedBox(width: 8),
              const Text('Generating PDF…', style: TextStyle(fontSize: 12, color: AppPalette.textMuted)),
            ],
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'View PDF', onPressed: _view),
        IconButton(icon: const Icon(Icons.print_outlined), tooltip: 'Print', onPressed: _print),
      ],
    );
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final String fileName;
  final Uint8List bytes;

  const _PdfViewerScreen({required this.fileName, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: false,
        initialPageFormat: null,
        // Unconstrained, the page stretches to the full window width and looks blown-up/blurry on a
        // wide desktop screen. Capping it renders the page at a natural, readable size; scroll-wheel
        // / pinch / double-click zoom (built into PdfPreview's InteractiveViewer) still works from there.
        maxPageWidth: 700,
      ),
    );
  }
}
