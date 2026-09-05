import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Maps a sidebar item's position to a keyboard shortcut and its display label, so the sidebar
/// badge (what the user sees) and the actual key binding (what CallbackShortcuts listens for) can
/// never drift apart — both come from this one function per index.
///
/// Ctrl+1..Ctrl+9 then Ctrl+0 cover the first 10 items; Ctrl+Shift+1..Ctrl+Shift+9 then
/// Ctrl+Shift+0 cover up to 10 more (20 total, well past the app's current 15 nav items).
class NavShortcuts {
  static LogicalKeySet? keySetFor(int index) {
    if (index < 10) {
      return LogicalKeySet(LogicalKeyboardKey.control, _digitKey(index));
    }
    if (index < 20) {
      return LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, _digitKey(index - 10));
    }
    return null;
  }

  static String? labelFor(int index) {
    if (index < 10) return '${(index + 1) % 10}';
    if (index < 20) return '⇧${(index - 10 + 1) % 10}';
    return null;
  }

  static LogicalKeyboardKey _digitKey(int i) {
    // i is 0-based item position; maps 0->'1' key ... 8->'9' key, 9->'0' key.
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
    return digitKeys[i % 10];
  }
}
