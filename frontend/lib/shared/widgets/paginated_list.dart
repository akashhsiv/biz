import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Footer control for a client-side-paginated [AppListCard] — "X–Y of Z" plus Prev/Next. Page state
/// itself lives in the calling screen (plain `int`, like every other bit of local UI state in this
/// app) and is handed back in via [onPageChange]; this widget has no state of its own.
class PaginationBar extends StatelessWidget {
  final int page; // 0-based
  final int pageCount;
  final int totalItems;
  final int itemsPerPage;
  final ValueChanged<int> onPageChange;

  const PaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : page * itemsPerPage + 1;
    final end = ((page + 1) * itemsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppPalette.border))),
      child: Row(
        children: [
          Text('$start–$end of $totalItems', style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
          const Spacer(),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 0 ? () => onPageChange(page - 1) : null,
          ),
          Text('${page + 1} / $pageCount', style: const TextStyle(fontSize: 12, color: AppPalette.textSecondary)),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right),
            onPressed: page < pageCount - 1 ? () => onPageChange(page + 1) : null,
          ),
        ],
      ),
    );
  }
}
