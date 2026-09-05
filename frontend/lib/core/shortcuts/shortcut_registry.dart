import 'package:flutter/foundation.dart';

/// Tracks which page's New/Refresh actions are "active" right now, independent of Flutter's focus
/// tree. `ListScreenShortcuts` previously used `CallbackShortcuts`, which only fires when the
/// currently-focused widget's focus chain passes through that screen's subtree - so Ctrl+N silently
/// stopped working the moment focus moved somewhere outside it (a dialog, which mounts in the root
/// Navigator's overlay rather than as a descendant of the screen that opened it - see
/// FormNavShortcuts - or simply no widget having focus at all, which is the common case right after
/// navigating to a page and before clicking anything).
///
/// This registry plus a single root-level `HardwareKeyboard` handler (GlobalShortcutsListener) fixes
/// that: whichever page is currently on screen registers itself as active, and the key handler reads
/// from here directly - so "is this page active" replaces "does some widget deep inside have focus"
/// as the condition for the shortcut to fire.
class PageShortcutRegistry {
  PageShortcutRegistry._();

  static Object? _activeToken;
  static VoidCallback? _onNew;
  static VoidCallback? _onRefresh;

  static void setActive(Object token, {VoidCallback? onNew, VoidCallback? onRefresh}) {
    _activeToken = token;
    _onNew = onNew;
    _onRefresh = onRefresh;
  }

  /// Only clears if `token` is still the currently-active one - guards against a page that's being
  /// torn down (or a tab losing visibility) from clobbering whichever page/tab became active after it.
  static void clearIfActive(Object token) {
    if (identical(_activeToken, token)) {
      _activeToken = null;
      _onNew = null;
      _onRefresh = null;
    }
  }

  /// Returns whether a callback was actually invoked, so the caller (a global key handler) only
  /// consumes the key event when something was there to handle it.
  static bool triggerNew() {
    final cb = _onNew;
    if (cb == null) return false;
    cb();
    return true;
  }

  static bool triggerRefresh() {
    final cb = _onRefresh;
    if (cb == null) return false;
    cb();
    return true;
  }
}
