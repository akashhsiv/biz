import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum ToastType { success, info, error }

/// Global navigator key so toasts can be shown from anywhere (including places with no [Scaffold]
/// in context, like a dialog's own callbacks) without threading a [BuildContext] through — attach
/// this to [MaterialApp.navigatorKey].
final appNavigatorKey = GlobalKey<NavigatorState>();

class _ToastEntry {
  final int id;
  final String message;
  final ToastType type;
  _ToastEntry(this.id, this.message, this.type);
}

/// Minimal, app-styled replacement for [ScaffoldMessenger.showSnackBar]: colored, top-right toasts
/// (green/blue/red for success/info/error) that overlay anything, including dialogs. Multiple
/// toasts stack in a column — each keeps its own dismiss timer — rather than one replacing or
/// overlapping another, since several actions can report results in quick succession.
class AppToast {
  static final List<_ToastEntry> _entries = [];
  static OverlayEntry? _overlayEntry;
  static int _nextId = 0;

  static void success(String message) => _show(message, ToastType.success);
  static void info(String message) => _show(message, ToastType.info);
  static void error(String message) => _show(message, ToastType.error);

  static void show(String message, ToastType type) => _show(message, type);

  static void _show(String message, ToastType type) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final entry = _ToastEntry(_nextId++, message, type);
    _entries.add(entry);

    _overlayEntry ??= OverlayEntry(builder: (context) => _ToastStack());
    if (_overlayEntry!.mounted) {
      _overlayEntry!.markNeedsBuild();
    } else {
      overlay.insert(_overlayEntry!);
    }

    Timer(const Duration(seconds: 4), () {
      _entries.removeWhere((e) => e.id == entry.id);
      if (_entries.isEmpty) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      } else {
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  static void _dismiss(int id) {
    _entries.removeWhere((e) => e.id == id);
    if (_entries.isEmpty) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }
}

class _ToastStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.of(AppToast._entries.reversed).map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ToastWidget(entry: e),
          );
        }).toList(),
      ),
    );
  }
}

class _ToastWidget extends StatelessWidget {
  final _ToastEntry entry;

  const _ToastWidget({required this.entry});

  (Color bg, Color fg, IconData icon) _style() => switch (entry.type) {
        ToastType.success => (AppPalette.successLight, AppPalette.successText, Icons.check_circle_outline),
        ToastType.info => (AppPalette.primaryLight, AppPalette.primaryDark, Icons.info_outline),
        ToastType.error => (AppPalette.errorLight, AppPalette.errorText, Icons.error_outline),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _style();
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GestureDetector(
          onTap: () => AppToast._dismiss(entry.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: fg.withValues(alpha: 0.25)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 10),
                Flexible(child: Text(entry.message, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
