import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Shared key combos so every screen's `CallbackShortcuts` uses exactly the same LogicalKeySet
/// instances for the same meaning — Ctrl+N always means "New", F5 always means "Refresh".
class AppKeys {
  static final ctrlN = LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN);
  static final ctrlS = LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS);
  static final f5 = LogicalKeySet(LogicalKeyboardKey.f5);
}
