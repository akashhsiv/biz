import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'stock_model.dart';
import 'stock_provider.dart';

const _pageSize = 20;

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _search = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(stockLevelsProvider);
    final auth = ref.watch(authControllerProvider);
    final canAdjust = auth.has(Permissions.stockAdjust);
    void openAdjust() => showDialog(context: context, builder: (_) => const _AdjustStockDialog());
    void refresh() => ref.invalidate(stockLevelsProvider);

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: canAdjust ? openAdjust : null,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        floatingActionButton: canAdjust ? AppFab(onPressed: openAdjust, tooltip: 'Adjust Stock (Ctrl+N)', label: 'Adjust Stock', icon: Icons.tune) : null,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Stock',
                subtitle: 'Current quantity on hand for every stock-tracked item',
                actions: [
                  SizedBox(
                    width: 240,
                    height: 40,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search stock...'),
                    ),
                  ),
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: levelsAsync.when(
                  data: (levels) {
                    final query = _search.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? levels
                        : levels.where((l) => l.name.toLowerCase().contains(query) || l.sku.toLowerCase().contains(query)).toList();

                    return AppListCard(
                      emptyMessage: query.isEmpty ? 'No stock items found.' : 'No stock items match "$query".',
                      emptyIcon: Icons.inventory_outlined,
                      columns: const [
                        AppListColumn('SKU', flex: 2),
                        AppListColumn('Name', flex: 4),
                        AppListColumn('Qty On Hand', flex: 2),
                      ],
                      itemCount: filtered.length,
                      itemsPerPage: _pageSize,
                      currentPage: _page,
                      onPageChange: (p) => setState(() => _page = p),
                      onRowTap: (i) => showDialog(context: context, builder: (_) => _MovementsDialog(item: filtered[i])),
                      cellsBuilder: (context, i) {
                        final l = filtered[i];
                        final isLow = l.quantityOnHand <= 5;
                        return [
                          Text(l.sku, style: const TextStyle(fontSize: 13)),
                          Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Row(
                            children: [
                              Text(l.quantityOnHand.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: isLow ? Colors.red : null)),
                              if (isLow) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                              ],
                            ],
                          ),
                        ];
                      },
                    );
                  },
                  loading: () => Card(child: SkeletonTableRows(columns: 3)),
                  error: (e, _) => Center(child: Text('Failed to load stock: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementsDialog extends ConsumerWidget {
  final StockLevel item;
  const _MovementsDialog({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider(item.itemId));

    return AlertDialog(
      title: Text('${item.name} — Movements'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: movementsAsync.when(
          data: (movements) => ListView.separated(
            itemCount: movements.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = movements[i];
              return ListTile(
                dense: true,
                title: Text('${movementTypeNames[m.movementType]} ${m.quantityDelta > 0 ? "+" : ""}${m.quantityDelta.toStringAsFixed(2)}'),
                subtitle: Text('${m.createdAt.toLocal()} · after: ${m.quantityAfter.toStringAsFixed(2)}${m.reason != null ? " · ${m.reason}" : ""}'),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load movements: $e'),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}

class _AdjustStockDialog extends ConsumerStatefulWidget {
  const _AdjustStockDialog();

  @override
  ConsumerState<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<_AdjustStockDialog> {
  String? _itemId;
  final _delta = TextEditingController();
  final _reason = TextEditingController();
  final _serialController = TextEditingController();
  final _batchController = TextEditingController();
  DateTime? _expiryDate;
  bool _saving = false;
  String? _error;

  Future<void> _save(List<StockLevel> levels) async {
    final delta = double.tryParse(_delta.text);
    if (_itemId == null || delta == null || delta == 0 || _reason.text.trim().isEmpty) {
      setState(() => _error = 'Select an item, a non-zero quantity, and a reason.');
      return;
    }

    final item = levels.firstWhere((l) => l.itemId == _itemId);
    final serialNumbers = _serialController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // A new unit being added always needs its own distinct serial - there is no FIFO to fall back to
    // when creating stock (unlike removing it, where the oldest-received unit is picked automatically).
    if (item.isSerialTracked && delta > 0 && serialNumbers.length != delta.toInt()) {
      setState(() => _error = 'Enter exactly ${delta.toInt()} serial number(s) for this item.');
      return;
    }
    if (item.isBatchTracked && delta > 0 && _batchController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a batch number for this item.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<void>(
      '/api/stock/adjustments',
      (_) {},
      body: {
        'itemId': _itemId,
        'quantityDelta': delta,
        'reason': _reason.text.trim(),
        'serialNumbers': serialNumbers.isEmpty ? null : serialNumbers,
        'batchNumber': _batchController.text.trim().isEmpty ? null : _batchController.text.trim(),
        'expiryDate': _expiryDate?.toIso8601String(),
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(stockLevelsProvider);
        Navigator.of(context).pop();
      case ApiFailure(message: final msg):
        setState(() {
          _saving = false;
          _error = msg;
        });
      case ApiNetworkError(message: final msg):
        setState(() {
          _saving = false;
          _error = 'Could not reach the Host: $msg';
        });
    }
  }

  @override
  void dispose() {
    _delta.dispose();
    _reason.dispose();
    _serialController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(stockLevelsProvider);
    final levels = levelsAsync.valueOrNull ?? [];
    final selectedItem = _itemId == null ? null : levels.where((l) => l.itemId == _itemId).firstOrNull;
    final delta = double.tryParse(_delta.text);
    final isIncrease = (delta ?? 0) > 0;

    return AlertDialog(
      title: const Text('Manual Stock Adjustment'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            levelsAsync.when(
              data: (levels) => DropdownButtonFormField<String>(
                initialValue: _itemId,
                decoration: const InputDecoration(labelText: 'Item'),
                items: levels.map((l) => DropdownMenuItem(value: l.itemId, child: Text('${l.name} (${l.quantityOnHand.toStringAsFixed(0)})'))).toList(),
                onChanged: (v) => setState(() => _itemId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load items.'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _delta,
              decoration: const InputDecoration(labelText: 'Quantity change (+/-)'),
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason (required)')),
            if (selectedItem != null && selectedItem.isSerialTracked) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _serialController,
                decoration: InputDecoration(
                  labelText: 'Serial Numbers (comma-separated)',
                  hintText: isIncrease ? 'Required — one per unit added' : 'Optional — blank removes the oldest unit(s)',
                ),
                maxLines: 2,
              ),
            ],
            if (selectedItem != null && selectedItem.isBatchTracked && isIncrease) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(controller: _batchController, decoration: const InputDecoration(labelText: 'Batch Number', isDense: true)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => _expiryDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Expiry (optional)', isDense: true),
                        child: Text(_expiryDate == null ? '-' : '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : () => _save(levels), child: const Text('Save')),
      ],
    );
  }
}
