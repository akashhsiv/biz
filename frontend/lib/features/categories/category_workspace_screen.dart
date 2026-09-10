import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_toast.dart';
import '../purchases/purchases_screen.dart';
import '../sales/sales_invoices_screen.dart';
import 'categories_provider.dart';
import 'category_model.dart';

/// Single top-level nav entry (see app.dart) covering every Category — a dropdown here switches
/// between them instead of each Category getting its own sidebar row, which got unwieldy once a
/// shop had more than a couple. Keeps the same per-category Purchase List / Sales List tabs.
class SalesHubScreen extends ConsumerStatefulWidget {
  const SalesHubScreen({super.key});

  @override
  ConsumerState<SalesHubScreen> createState() => _SalesHubScreenState();
}

class _SalesHubScreenState extends ConsumerState<SalesHubScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No categories yet.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create a Category'),
                    onPressed: () => showDialog(context: context, builder: (_) => const ManageCategoriesDialog()),
                  ),
                ],
              ),
            );
          }

          final selected = categories.firstWhere(
            (c) => c.id == _selectedCategoryId,
            orElse: () => categories.first,
          );

          return CategoryWorkspaceScreen(
            key: ValueKey(selected.id),
            category: selected,
            categoryPicker: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected.id,
                items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load categories: $e')),
      ),
    );
  }
}

/// The Purchase List / Sales List tabs for one Category — [categoryPicker] replaces the plain
/// title so the caller (SalesHubScreen) can let the user switch categories in place, but this
/// widget stays usable standalone too if a plain title is passed instead.
class CategoryWorkspaceScreen extends StatelessWidget {
  final ItemCategory category;
  final Widget? categoryPicker;
  const CategoryWorkspaceScreen({super.key, required this.category, this.categoryPicker});

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
                    child: categoryPicker ??
                        Text(category.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: const Text('Manage Categories'),
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
