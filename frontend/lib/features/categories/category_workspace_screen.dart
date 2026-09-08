import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_toast.dart';
import '../purchases/purchases_screen.dart';
import '../sales/sales_invoices_screen.dart';
import 'categories_provider.dart';
import 'category_model.dart';

/// Opened from a Category's sidebar entry (see app.dart, which builds one NavItem per active
/// ItemCategory) — two tabs scoped to this category: the Purchase List (POs whose CategoryId is
/// this one) and the Sales List (invoices whose CategoryId is this one), each with its own filter
/// bar and "+ New" action.
class CategoryWorkspaceScreen extends StatelessWidget {
  final ItemCategory category;
  const CategoryWorkspaceScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: Column(
          children: [
            Container(
              color: AppPalette.card,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(category.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: 'Manage Categories',
                    icon: const Icon(Icons.category_outlined, size: 20),
                    onPressed: () => showDialog(context: context, builder: (_) => const ManageCategoriesDialog()),
                  ),
                ],
              ),
            ),
            Container(
              color: AppPalette.card,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppPalette.primary,
                unselectedLabelColor: AppPalette.textSecondary,
                indicatorColor: AppPalette.primary,
                tabs: [Tab(text: 'Purchase List'), Tab(text: 'Sales List')],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CategoryPurchaseOrdersTab(categoryId: category.id),
                  SalesInvoicesScreen(categoryId: category.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal Shop-Admin capability to create a new Item Category — reachable from the category nav's
/// own overflow menu (see app.dart) rather than a dedicated management screen, per the judgment
/// call this doesn't need to be elaborate.
class ManageCategoriesDialog extends ConsumerStatefulWidget {
  const ManageCategoriesDialog({super.key});

  @override
  ConsumerState<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends ConsumerState<ManageCategoriesDialog> {
  final _nameController = TextEditingController();
  bool _saving = false;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final error = await createCategory(ref, name);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      AppToast.error(error);
    } else {
      _nameController.clear();
      ref.invalidate(categoriesProvider);
      AppToast.success('Category created.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            categoriesAsync.when(
              data: (categories) => Column(
                children: categories.map((c) => ListTile(dense: true, title: Text(c.name))).toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load categories: $e'),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'New category name', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _saving ? null : _create, child: const Text('Add')),
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
