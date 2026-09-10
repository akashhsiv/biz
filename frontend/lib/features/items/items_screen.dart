import 'package:flutter/material.dart';
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
import '../categories/categories_provider.dart';
import 'brand_model.dart';
import 'brands_provider.dart';
import 'item_model.dart';
import 'items_provider.dart';

const _pageSize = 20;

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final _search = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.has(Permissions.itemsManage);
    void openCreate() => showDialog(context: context, builder: (_) => const _CreateItemDialog());
    void refresh() => ref.invalidate(itemsProvider);

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: canManage ? openCreate : null,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        floatingActionButton: canManage
            ? AppFab(onPressed: openCreate, tooltip: 'New Item (Ctrl+N)', label: 'New Item')
            : null,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Items',
                subtitle: 'Manage your catalog of stock and non-stock items',
                actions: [
                  SizedBox(
                    width: 240,
                    height: 40,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search items...'),
                    ),
                  ),
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: itemsAsync.when(
                  data: (items) {
                    final query = _search.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? items
                        : items.where((it) => it.name.toLowerCase().contains(query) || it.sku.toLowerCase().contains(query)).toList();

                    return AppListCard(
                      emptyMessage: query.isEmpty ? 'No items yet. Add your first item to start building quotations and invoices.' : 'No items match "$query".',
                      emptyIcon: Icons.inventory_2_outlined,
                      columns: const [
                        AppListColumn('SKU', flex: 2),
                        AppListColumn('Name', flex: 4),
                        AppListColumn('Brand', flex: 2),
                        AppListColumn('Unit', flex: 2),
                        AppListColumn('Kind', flex: 2),
                        AppListColumn('Stock', flex: 2),
                        AppListColumn('Price', flex: 2),
                        AppListColumn('Tax %', flex: 1),
                      ],
                      itemCount: filtered.length,
                      itemsPerPage: _pageSize,
                      currentPage: _page,
                      onPageChange: (p) => setState(() => _page = p),
                      cellsBuilder: (context, i) {
                        final it = filtered[i];
                        final isLow = it.itemKind == ItemKind.stock && it.stockOnHand < 10;
                        return [
                          Text(it.sku, style: const TextStyle(fontSize: 13)),
                          Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(it.brandName ?? '—', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          Text(it.unit, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          Text(it.itemKind == ItemKind.stock ? 'Stock' : 'Non-Stock', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          it.itemKind == ItemKind.stock
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(it.stockOnHand.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.w600, color: isLow ? Colors.orange.shade800 : null)),
                                    if (isLow) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade800),
                                    ],
                                  ],
                                )
                              : const Text('—'),
                          Text('₹${it.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                          Text('${it.taxRatePercent.toStringAsFixed(0)}%', style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                        ];
                      },
                    );
                  },
                  loading: () => Card(child: SkeletonTableRows(columns: 8)),
                  error: (e, _) => Center(child: Text('Failed to load items: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateItemDialog extends ConsumerStatefulWidget {
  const _CreateItemDialog();

  @override
  ConsumerState<_CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends ConsumerState<_CreateItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _name = TextEditingController();
  final _hsnCode = TextEditingController();
  final _purchasePrice = TextEditingController(text: '0');
  final _sellingPrice = TextEditingController(text: '0');
  final _taxRatePercent = TextEditingController(text: '0');
  String _unit = commonItemUnits.first;
  ItemKind _kind = ItemKind.stock;
  bool _batchTracked = false;
  bool _serialTracked = false;
  bool _saving = false;
  String? _error;
  String? _categoryId;
  String? _brandId;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/items',
      (json) => json as Map<String, dynamic>,
      body: {
        'sku': _sku.text.trim(),
        'name': _name.text.trim(),
        'categoryId': _categoryId,
        'brandId': _brandId,
        'unit': _unit,
        'itemKind': _kind.index,
        'purchasePrice': double.tryParse(_purchasePrice.text) ?? 0,
        'sellingPrice': double.tryParse(_sellingPrice.text) ?? 0,
        'taxRatePercent': double.tryParse(_taxRatePercent.text) ?? 0,
        'hsnCode': _hsnCode.text.trim().isEmpty ? null : _hsnCode.text.trim(),
        'isBatchTracked': _batchTracked,
        'isSerialTracked': _serialTracked,
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(itemsProvider);
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Item'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _sku,
                decoration: const InputDecoration(labelText: 'SKU *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 8),
              TextField(controller: _hsnCode, decoration: const InputDecoration(labelText: 'HSN/SAC Code (optional)')),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final categoriesAsync = ref.watch(categoriesProvider);
                  return categoriesAsync.when(
                    data: (categories) {
                      // Default to the shop's Cash Bill category (or the first available) so a new
                      // item is never left without a category, since Purchase/Sales creation now
                      // requires every line item to belong to the document's chosen category.
                      if (_categoryId == null && categories.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _categoryId = categories.first.id);
                        });
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        validator: (v) => v == null ? 'Category is required' : null,
                        onChanged: (v) => setState(() {
                          _categoryId = v;
                          _brandId = null; // a brand belongs to exactly one category - clear on switch
                        }),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Failed to load categories: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (_categoryId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final brandsAsync = ref.watch(brandsProvider(_categoryId));
                    return brandsAsync.when(
                      data: (brands) => Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: _brandId,
                              decoration: const InputDecoration(labelText: 'Brand (optional)'),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('No brand')),
                                ...brands.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
                              ],
                              onChanged: (v) => setState(() => _brandId = v),
                            ),
                          ),
                          IconButton(
                            tooltip: 'New Brand',
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () async {
                              final created = await showDialog<Brand>(
                                context: context,
                                builder: (_) => _NewBrandDialog(categoryId: _categoryId!),
                              );
                              if (created != null) {
                                ref.invalidate(brandsProvider(_categoryId));
                                setState(() => _brandId = created.id);
                              }
                            },
                          ),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Failed to load brands: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: commonItemUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<ItemKind>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: 'Kind'),
                      items: const [
                        DropdownMenuItem(value: ItemKind.stock, child: Text('Stock')),
                        DropdownMenuItem(value: ItemKind.nonStock, child: Text('Non-Stock')),
                      ],
                      onChanged: (v) => setState(() => _kind = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _purchasePrice, decoration: const InputDecoration(labelText: 'Purchase Price'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _sellingPrice, decoration: const InputDecoration(labelText: 'Selling Price'), keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _taxRatePercent,
                decoration: const InputDecoration(labelText: 'Tax Rate % (GST)', suffixText: '%'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              if (_kind == ItemKind.stock) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Batch tracked'),
                  subtitle: const Text('Group stock by batch number + expiry'),
                  value: _batchTracked,
                  onChanged: (v) => setState(() {
                    _batchTracked = v ?? false;
                    if (_batchTracked) _serialTracked = false;
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Serial tracked'),
                  subtitle: const Text('One serial number per physical unit'),
                  value: _serialTracked,
                  onChanged: (v) => setState(() {
                    _serialTracked = v ?? false;
                    if (_serialTracked) _batchTracked = false;
                  }),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

/// Minimal inline brand creation, reached from the "+" next to the Brand dropdown above — this is
/// the only place in the app a Brand can be created, since a Brand always needs a Category and this
/// dialog already knows which one is selected.
class _NewBrandDialog extends ConsumerStatefulWidget {
  final String categoryId;
  const _NewBrandDialog({required this.categoryId});

  @override
  ConsumerState<_NewBrandDialog> createState() => _NewBrandDialogState();
}

class _NewBrandDialogState extends ConsumerState<_NewBrandDialog> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final created = await createBrand(ref, name, widget.categoryId, onError: (msg) => _error = msg);

    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop(created);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Brand'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Brand name *'), onSubmitted: (_) => _save()),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Create')),
      ],
    );
  }
}
