import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_variant.dart';
import '../../core/theme/app_theme.dart';

/// Replaces the native Windows title bar (confirmed decision 2026-08-28): sidebar-themed, draggable,
/// with its own minimize/maximize/close controls and a live clock. Mounted once at the app root (see
/// app.dart/main.dart) above every screen and dialog, so the window is always controllable even
/// before login/connection. Wrapped in its own transparent Material so IconButton ink effects work
/// without needing a MaterialApp ancestor - this sits above ErpApp's MaterialApp in the widget tree.
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: 32,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppPalette.sidebarBackground, AppPalette.sidebarBackgroundEnd],
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.storefront, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Text(AppVariant.appTitle, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            Expanded(
              child: DragToMoveArea(
                child: Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Text(
                    DateFormat('HH:mm:ss').format(_now),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            _TitleBarButton(icon: Icons.remove, tooltip: 'Minimize', onPressed: () => windowManager.minimize()),
            _TitleBarButton(
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              tooltip: _maximized ? 'Restore' : 'Maximize',
              iconSize: 13,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _TitleBarButton(
              icon: Icons.close,
              tooltip: 'Close',
              hoverColor: const Color(0xFFE81123),
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;
  final Color? hoverColor;

  const _TitleBarButton({required this.icon, required this.tooltip, required this.onPressed, this.iconSize = 15, this.hoverColor});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onPressed,
        hoverColor: hoverColor ?? Colors.white.withValues(alpha: 0.12),
        child: SizedBox(width: 44, height: 32, child: Icon(icon, size: iconSize, color: Colors.white)),
      ),
    );
  }
}
