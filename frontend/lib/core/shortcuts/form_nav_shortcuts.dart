import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Enter / arrow-down moves focus to the next field, arrow-up moves to the previous one — applied
/// once at the app root (via MaterialApp's `builder`) so it covers every form, including the ones
/// shown as dialogs (those mount in the root Navigator's overlay, not as a descendant of whatever
/// screen opened them, so wrapping any individual screen would miss them).
///
/// Deliberately does NOT touch individual TextFields. A multi-line field's own EditableText
/// consumes Enter (to insert a newline) and arrow keys (to move the cursor within the text) before
/// the key event ever reaches this ancestor — so multi-line editing (Address, Terms & Conditions,
/// etc.) keeps working exactly as before; only single-line fields, where EditableText has nothing
/// useful to do with Enter/vertical-arrow and lets the event bubble, pick up this behavior.
class FormNavShortcuts extends StatelessWidget {
  final Widget child;

  const FormNavShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const NextFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const NextFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const NextFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const PreviousFocusIntent(),
      },
      child: child,
    );
  }
}
