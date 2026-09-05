import 'package:flutter/foundation.dart';

/// AppShell's sidebar-level shortcuts (nav switching, logout, help). Previously bound via
/// CallbackShortcuts wrapped in a `Focus(autofocus: true)` - which, like the page-level New/Refresh
/// shortcuts before PageShortcutRegistry existed, only fires when that exact Focus node actually
/// holds focus. In practice something else (a list screen's search field, a dialog, simply nothing
/// at all right after the app opens) ends up with focus instead, so these silently never fired.
/// Moved onto the same focus-independent HardwareKeyboard dispatch as PageShortcutRegistry - see
/// GlobalShortcutsListener, which calls these instead of relying on the widget focus tree.
class AppShellShortcuts {
  AppShellShortcuts._();

  static void Function(int index)? _onNavigate;
  static VoidCallback? _onLogout;
  static VoidCallback? _onHelp;

  /// AppShell re-registers on every build (cheap - just a few static field writes) so the closures
  /// always capture the current `visibleItems`/context/ref rather than a stale one from an earlier build.
  static void register({required void Function(int index) onNavigate, required VoidCallback onLogout, required VoidCallback onHelp}) {
    _onNavigate = onNavigate;
    _onLogout = onLogout;
    _onHelp = onHelp;
  }

  static void clear() {
    _onNavigate = null;
    _onLogout = null;
    _onHelp = null;
  }

  static bool triggerNavigate(int index) {
    final cb = _onNavigate;
    if (cb == null) return false;
    cb(index);
    return true;
  }

  static bool triggerLogout() {
    final cb = _onLogout;
    if (cb == null) return false;
    cb();
    return true;
  }

  static bool triggerHelp() {
    final cb = _onHelp;
    if (cb == null) return false;
    cb();
    return true;
  }
}
