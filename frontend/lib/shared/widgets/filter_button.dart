import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A status/category filter — looks like a normal (enabled) outlined button and opens a dropdown
/// menu on tap. Replaces the `PopupMenuButton` wrapping a `child: OutlinedButton(onPressed: null,
/// ...)` pattern copy-pasted across every master-detail screen: giving that inner button a null
/// `onPressed` made Flutter render it in its *disabled* colors (muted/greyed text and icon) even
/// though the button worked fine — the tap target was the surrounding `PopupMenuButton`, not the
/// button itself. This widget is the tap target and is never actually disabled, so it always renders
/// with normal, legible colors.
class FilterButton<T> extends StatelessWidget {
  final T? value;
  final String allLabel;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  const FilterButton({
    super.key,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T?>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<T?>(value: null, child: Text(allLabel)),
        for (final o in options) PopupMenuItem<T?>(value: o, child: Text(labelOf(o))),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 16, color: AppPalette.textSecondary),
            const SizedBox(width: 8),
            Text(
              value == null ? allLabel : labelOf(value as T),
              style: const TextStyle(fontSize: 13, color: AppPalette.textPrimary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 16, color: AppPalette.textMuted),
          ],
        ),
      ),
    );
  }
}
