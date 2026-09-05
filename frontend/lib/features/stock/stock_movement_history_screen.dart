import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'stock_model.dart';
import 'stock_movement_model.dart';
import 'stock_provider.dart';

/// Chronological ledger of every stock change for one item, backed by `GET /api/stock/movements`.
/// Pushed from [StockScreen] via the "History" action on a balance row.
class StockMovementHistoryScreen extends ConsumerWidget {
  final StockLevel item;
  const StockMovementHistoryScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider(item.itemId));

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(title: Text('${item.name} — Stock History')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Movement History',
              subtitle: '${item.sku} · currently ${item.quantityOnHand.toStringAsFixed(0)} on hand',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(stockMovementsProvider(item.itemId)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: movementsAsync.when(
                data: (movements) => AppListCard(
                  emptyMessage: 'No stock movements recorded for this item yet.',
                  emptyIcon: Icons.history,
                  columns: const [
                    AppListColumn('Date', flex: 3),
                    AppListColumn('Type', flex: 2),
                    AppListColumn('Change', flex: 2, numeric: true),
                    AppListColumn('Before → After', flex: 3, numeric: true),
                    AppListColumn('Reference', flex: 2),
                    AppListColumn('Reason', flex: 3),
                  ],
                  itemCount: movements.length,
                  cellsBuilder: (context, i) {
                    final m = movements[i];
                    final isIncrease = m.quantityDelta > 0;
                    return [
                      Text(_formatDate(m.createdAt), style: const TextStyle(fontSize: 13)),
                      Text(m.movementType.label, style: const TextStyle(fontSize: 13)),
                      Text(
                        '${isIncrease ? "+" : ""}${m.quantityDelta.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isIncrease ? Colors.green.shade700 : Colors.red.shade700),
                      ),
                      Text('${m.quantityBefore.toStringAsFixed(2)} → ${m.quantityAfter.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                      Text(m.referenceType.label, style: const TextStyle(fontSize: 12, color: AppPalette.textMuted)),
                      Text(m.reason ?? '-', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    ];
                  },
                ),
                loading: () => const Card(child: SkeletonTableRows(columns: 6)),
                error: (e, _) => Center(child: Text('Failed to load stock movements: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
