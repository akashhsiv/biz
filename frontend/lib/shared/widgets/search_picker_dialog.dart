import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A modal search-and-pick dialog: type to filter, Arrow Up/Down to highlight, Enter to select,
/// Escape to close. Used by [SearchableDropdown] for any list long enough that scrolling a plain
/// dropdown menu gets tedious (customers, items, suppliers).
class SearchPickerDialog<T> extends StatefulWidget {
  final String title;
  final String hint;
  final List<T> items;
  final String Function(T item) displayLabel;
  final String Function(T item)? secondaryLabel;
  final bool Function(T item, String query) filterFn;
  final T? selectedItem;
  final String? initialQuery;

  const SearchPickerDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.items,
    required this.displayLabel,
    required this.filterFn,
    this.secondaryLabel,
    this.selectedItem,
    this.initialQuery,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String hint,
    required List<T> items,
    required String Function(T item) displayLabel,
    required bool Function(T item, String query) filterFn,
    String Function(T item)? secondaryLabel,
    T? selectedItem,
    String? initialQuery,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => SearchPickerDialog<T>(
        title: title,
        hint: hint,
        items: items,
        displayLabel: displayLabel,
        filterFn: filterFn,
        secondaryLabel: secondaryLabel,
        selectedItem: selectedItem,
        initialQuery: initialQuery,
      ),
    );
  }

  @override
  State<SearchPickerDialog<T>> createState() => _SearchPickerDialogState<T>();
}

class _SearchPickerDialogState<T> extends State<SearchPickerDialog<T>> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  int _highlightedIndex = -1;
  late List<T> _filtered;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _filtered = widget.items.where((item) => widget.filterFn(item, widget.initialQuery!)).toList();
    } else {
      _filtered = widget.items;
    }
    if (widget.selectedItem != null) {
      final idx = _filtered.indexWhere((item) => widget.displayLabel(item) == widget.displayLabel(widget.selectedItem as T));
      if (idx >= 0) _highlightedIndex = idx;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      _filtered = query.trim().isEmpty ? widget.items : widget.items.where((item) => widget.filterFn(item, query)).toList();
      _highlightedIndex = -1;
    });
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 48.0;
    final offset = (index * itemHeight) - 120;
    _scrollController.animateTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent), duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final total = _filtered.length;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (total == 0) return KeyEventResult.handled;
      setState(() => _highlightedIndex = (_highlightedIndex < 0 || _highlightedIndex >= total - 1) ? 0 : _highlightedIndex + 1);
      _scrollToIndex(_highlightedIndex);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (total == 0) return KeyEventResult.handled;
      setState(() => _highlightedIndex = (_highlightedIndex <= 0) ? total - 1 : _highlightedIndex - 1);
      _scrollToIndex(_highlightedIndex);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (total > 0 && _highlightedIndex >= 0 && _highlightedIndex < total) {
        Navigator.of(context).pop(_filtered[_highlightedIndex]);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  Text(widget.title, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(context).pop(), splashRadius: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Focus(
                onKeyEvent: (_, event) => _handleKey(event),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No results found')))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      itemExtent: 48,
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        final isHighlighted = _highlightedIndex == i;
                        final isSelected = widget.selectedItem != null && widget.displayLabel(item) == widget.displayLabel(widget.selectedItem as T);

                        return InkWell(
                          onTap: () => Navigator.of(context).pop(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            color: isHighlighted ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.displayLabel(item),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? theme.colorScheme.primary : null,
                                    ),
                                  ),
                                ),
                                if (widget.secondaryLabel != null)
                                  Text(widget.secondaryLabel!(item), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                if (isSelected) ...[const SizedBox(width: 8), Icon(Icons.check, color: theme.colorScheme.primary, size: 16)],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
