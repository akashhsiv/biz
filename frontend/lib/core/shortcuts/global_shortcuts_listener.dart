import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell_shortcuts.dart';
import 'shortcut_registry.dart';

/// Applied once at the app root (alongside FormNavShortcuts) so Ctrl+N/F5 fire for whichever page
/// is currently active regardless of what has keyboard focus - see PageShortcutRegistry for why that
/// matters. Uses HardwareKeyboard directly instead of Shortcuts/CallbackShortcuts specifically
/// because those are focus-tree-based; this needs to bypass focus entirely.
class GlobalShortcutsListener extends StatefulWidget {
  final Widget child;

  const GlobalShortcutsListener({super.key, required this.child});

  @override
  State<GlobalShortcutsListener> createState() => _GlobalShortcutsListenerState();
}

class _GlobalShortcutsListenerState extends State<GlobalShortcutsListener> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyN) {
      return PageShortcutRegistry.triggerNew();
    }
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      return PageShortcutRegistry.triggerRefresh();
    }
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      return AppShellShortcuts.triggerHelp();
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyL) {
      return AppShellShortcuts.triggerLogout();
    }
    if (isCtrl) {
      final digitIndex = _digitIndex(event.logicalKey);
      if (digitIndex != null) {
        return AppShellShortcuts.triggerNavigate(isShift ? digitIndex + 10 : digitIndex);
      }
    }
    return false;
  }

  /// Reverse of NavShortcuts._digitKey: maps a pressed digit key back to its 0-based nav index
  /// (digit1->0 ... digit9->8, digit0->9).
  static int? _digitIndex(LogicalKeyboardKey key) {
    const digitKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.digit0,
    ];
    final i = digitKeys.indexOf(key);
    return i == -1 ? null : i;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
