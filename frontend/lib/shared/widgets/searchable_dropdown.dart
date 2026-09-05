import 'package:flutter/material.dart';

import 'search_picker_dialog.dart';

/// A dropdown-style field that opens a searchable picker instead of a plain Material dropdown
/// menu — much faster to use once the list (customers, items, suppliers) grows past a handful of
/// entries, since typing filters instead of scrolling. Shows the same arrow-down affordance as a
/// regular dropdown so it still reads as "tap to choose one of these".
class SearchableDropdown<T> extends FormField<T> {
  SearchableDropdown({
    super.key,
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T item) itemLabel,
    String Function(T item)? itemSecondaryLabel,
    bool Function(T item, String query)? filterFn,
    required ValueChanged<T?> onChanged,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    super.validator,
  }) : super(
          initialValue: value,
          builder: (state) {
            void openPicker() async {
              if (items.isEmpty) return;
              final result = await SearchPickerDialog.show<T>(
                context: state.context,
                title: 'Select $label',
                hint: 'Search $label...',
                items: items,
                displayLabel: itemLabel,
                secondaryLabel: itemSecondaryLabel,
                filterFn: filterFn ?? (item, query) => itemLabel(item).toLowerCase().contains(query.toLowerCase()),
                selectedItem: value,
              );
              if (result != null) {
                onChanged(result);
                state.didChange(result);
              }
              if (nextFocus != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => nextFocus.requestFocus());
              }
            }

            return InkWell(
              onTap: openPicker,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  errorText: state.errorText,
                ),
                child: Focus(
                  focusNode: focusNode,
                  onKeyEvent: (_, event) {
                    if (event.logicalKey.keyLabel.length == 1 || event.logicalKey.keyLabel == 'Enter' || event.logicalKey.keyLabel == 'Space') {
                      openPicker();
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Text(
                    value == null ? 'Select $label' : itemLabel(value),
                    style: value == null ? TextStyle(color: Theme.of(state.context).hintColor) : null,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        );
}
