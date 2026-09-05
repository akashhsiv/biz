import 'package:flutter/material.dart';

/// Provides an Overlay ancestor for content that needs one (e.g. CustomTitleBar's Tooltips) but
/// sits outside MaterialApp's own Navigator/Overlay. NOT the same as `Overlay(initialEntries:
/// [OverlayEntry(builder: ...)])` directly - that only reads initialEntries once at creation and
/// silently ignores it on every later rebuild, so wrapping MaterialApp's `child` (which changes as
/// the app navigates between ConnectionScreen/LoginScreen/AppShell) that way freezes the UI on
/// whatever screen was showing the first time it mounted. This keeps one persistent OverlayEntry
/// alive and explicitly tells it to rebuild whenever the wrapped child actually changes.
class OverlayHost extends StatefulWidget {
  final Widget child;
  const OverlayHost({super.key, required this.child});

  @override
  State<OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<OverlayHost> {
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(builder: (context) => widget.child);
  }

  @override
  void didUpdateWidget(covariant OverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  // No manual disposal of _entry here - the Overlay widget built below owns it once mounted and
  // disposes it itself when torn down; calling dispose() again here hits Flutter's own assertion
  // that an OverlayEntry must be removed from its Overlay before being disposed.

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
