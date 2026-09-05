import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'empty_state.dart';
import 'paginated_list.dart';

/// One column of an [AppListCard] — label the header shows, and its flex weight (matching Expanded's).
class AppListColumn {
  final String label;
  final int flex;
  final bool numeric;
  const AppListColumn(this.label, {this.flex = 1, this.numeric = false});
}

/// Shared "header row + rows" list widget, replacing the Card/Column/Divider/ListView.separated
/// block that was hand-copied into every list screen (Customers, Items, Stock, Deposits, Users,
/// Quotations, ...) with its own slightly different padding, hover behavior (usually none at all),
/// and empty state. One widget now owns: consistent padding/typography, a hover highlight on tap
/// rows (that copy-pasted pattern never had one), and a real empty state instead of a bare
/// `Text('No data.')` centered in space.
class AppListCard extends StatelessWidget {
  final List<AppListColumn> columns;
  final int itemCount;

  /// Returns the cell widgets for row [index] — must match [columns] in length/order. AppListCard
  /// wraps them in the Expanded(flex:)/Row/padding itself so every row lines up identically.
  final List<Widget> Function(BuildContext context, int index) cellsBuilder;

  final void Function(int index)? onRowTap;

  /// For master-detail lists (Quotations, Sales Invoices, ...) where the tapped row stays
  /// highlighted while its detail panel is open, distinct from the transient hover highlight.
  final bool Function(int index)? isSelected;

  final String emptyMessage;
  final IconData emptyIcon;

  /// True for a card embedded inside an already-scrolling parent (e.g. a report page's
  /// SingleChildScrollView) with no bounded height to give it — lays rows out in a plain Column
  /// instead of a ListView.separated, sized to its content like the DataTable it used to be. Only
  /// use this for lists that are always short (report breakdowns); a real list screen with hundreds
  /// of rows still needs the default virtualized ListView inside its own Expanded.
  final bool shrinkWrap;

  /// When set, only this many rows are shown at once and a [PaginationBar] footer appears — pure
  /// client-side slicing of the already-fetched [itemCount] rows, no query/API change. Page state
  /// lives in the calling screen; null (the default) keeps every other, still-unpaginated screen
  /// showing its full list exactly as before.
  final int? itemsPerPage;
  final int currentPage;
  final ValueChanged<int>? onPageChange;

  const AppListCard({
    super.key,
    required this.columns,
    required this.itemCount,
    required this.cellsBuilder,
    this.onRowTap,
    this.isSelected,
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.shrinkWrap = false,
    this.itemsPerPage,
    this.currentPage = 0,
    this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    final perPage = itemsPerPage;
    final pageCount = perPage == null ? 1 : (itemCount / perPage).ceil().clamp(1, 1 << 30);
    final page = currentPage.clamp(0, pageCount - 1);
    final start = perPage == null ? 0 : page * perPage;
    final end = perPage == null ? itemCount : (start + perPage).clamp(0, itemCount);
    final pageItemCount = end - start;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppPalette.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppPalette.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4),
              child: Row(
                children: [
                  for (final c in columns)
                    Expanded(
                      flex: c.flex,
                      child: Text(c.label.toUpperCase(), textAlign: c.numeric ? TextAlign.right : TextAlign.left),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          if (itemCount == 0)
            shrinkWrap
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: EmptyState(icon: emptyIcon, title: emptyMessage))
                : Expanded(child: EmptyState(icon: emptyIcon, title: emptyMessage))
          else if (shrinkWrap)
            Column(
              children: [
                for (var i = start; i < end; i++) ...[
                  if (i > start) const Divider(height: 1),
                  _buildRow(context, i),
                ],
              ],
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: pageItemCount,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, j) => _buildRow(context, start + j),
              ),
            ),
          if (perPage != null && itemCount > 0 && onPageChange != null)
            PaginationBar(page: page, pageCount: pageCount, totalItems: itemCount, itemsPerPage: perPage, onPageChange: onPageChange!),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int i) {
    final cells = cellsBuilder(context, i);
    final selected = isSelected?.call(i) ?? false;
    final row = Container(
      color: selected ? AppPalette.primaryLight : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (var c = 0; c < columns.length; c++)
            Expanded(
              flex: columns[c].flex,
              child: Align(alignment: columns[c].numeric ? Alignment.centerRight : Alignment.centerLeft, child: cells[c]),
            ),
        ],
      ),
    );

    if (onRowTap == null) return row;
    return InkWell(
      onTap: () => onRowTap!(i),
      hoverColor: selected ? null : AppPalette.primaryLight.withValues(alpha: 0.5),
      child: row,
    );
  }
}
