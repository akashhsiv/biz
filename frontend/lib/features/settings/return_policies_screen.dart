import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../categories/categories_provider.dart';
import '../categories/category_model.dart';
import 'return_policies_provider.dart';
import 'return_policy_model.dart';

/// Minimal Shop-Admin screen for Return Policies (Name, optional Category, Return Window in days,
/// Restocking Fee %) — list + create + deactivate, mirroring the simple-CRUD pattern used for
/// Categories/Brands. Reached from its own top-level nav entry (see app.dart) rather than nested
/// inside Shop Configuration, since it's gated by return_policies.manage rather than
/// company_settings.manage — a Sales Supervisor with the former but not the latter still needs to
/// reach it.
class ReturnPoliciesScreen extends ConsumerStatefulWidget {
  const ReturnPoliciesScreen({super.key});

  @override
  ConsumerState<ReturnPoliciesScreen> createState() => _ReturnPoliciesScreenState();
}

class _ReturnPoliciesScreenState extends ConsumerState<ReturnPoliciesScreen> {
  void _showCreateDialog() {
    showDialog(context: context, builder: (_) => const _ReturnPolicyFormDialog());
  }

  Future<void> _deactivate(ReturnPolicy policy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Return Policy'),
        content: Text('Deactivate "${policy.name}"? It will no longer be available for new returns.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await deactivateReturnPolicy(ref, policy.id);
    if (!mounted) return;

    if (error != null) {
      AppToast.error(error);
    } else {
      ref.invalidate(returnPoliciesProvider);
      AppToast.success('Return policy deactivated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final policiesAsync = ref.watch(returnPoliciesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.has(Permissions.returnPoliciesManage);
    void refresh() {
      ref.invalidate(returnPoliciesProvider);
      ref.invalidate(categoriesProvider);
    }

    String categoryName(String? categoryId) {
      if (categoryId == null) return 'All categories';
      final categories = categoriesAsync.valueOrNull ?? const <ItemCategory>[];
      for (final c in categories) {
        if (c.id == categoryId) return c.name;
      }
      return categoryId;
    }

    return Scaffold(
      backgroundColor: AppPalette.surface,
      floatingActionButton:
          canManage ? AppFab(onPressed: _showCreateDialog, tooltip: 'New Return Policy', label: 'New Return Policy') : null,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Return Policies',
              subtitle: 'Return window and restocking fee rules used by Sales Returns',
              actions: [
                OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: policiesAsync.when(
                data: (policies) => AppListCard(
                  emptyMessage: 'No return policies yet. Add your first one.',
                  emptyIcon: Icons.assignment_return_outlined,
                  columns: const [
                    AppListColumn('Name', flex: 3),
                    AppListColumn('Category', flex: 2),
                    AppListColumn('Window (days)', flex: 2, numeric: true),
                    AppListColumn('Restocking Fee %', flex: 2, numeric: true),
                    AppListColumn('Actions', flex: 2),
                  ],
                  itemCount: policies.length,
                  cellsBuilder: (context, i) {
                    final p = policies[i];
                    return [
                      Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(categoryName(p.categoryId), style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                      Text('${p.returnWindowDays}', style: const TextStyle(fontSize: 13)),
                      Text(p.restockingFeePercent.toStringAsFixed(2), style: const TextStyle(fontSize: 13)),
                      canManage
                          ? IconButton(
                              icon: const Icon(Icons.block, size: 18),
                              tooltip: 'Deactivate',
                              onPressed: () => _deactivate(p),
                            )
                          : const SizedBox.shrink(),
                    ];
                  },
                ),
                loading: () => const Card(child: SkeletonTableRows(columns: 5)),
                error: (e, _) => Center(child: Text('Failed to load return policies: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnPolicyFormDialog extends ConsumerStatefulWidget {
  const _ReturnPolicyFormDialog();

  @override
  ConsumerState<_ReturnPolicyFormDialog> createState() => _ReturnPolicyFormDialogState();
}

class _ReturnPolicyFormDialogState extends ConsumerState<_ReturnPolicyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _returnWindowDays = TextEditingController(text: '7');
  final _restockingFeePercent = TextEditingController(text: '0');
  String? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _returnWindowDays.dispose();
    _restockingFeePercent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await createReturnPolicy(
      ref,
      name: _name.text.trim(),
      categoryId: _categoryId,
      returnWindowDays: int.tryParse(_returnWindowDays.text.trim()) ?? 0,
      restockingFeePercent: double.tryParse(_restockingFeePercent.text.trim()) ?? 0,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
    } else {
      ref.invalidate(returnPoliciesProvider);
      Navigator.of(context).pop();
      AppToast.success('Return policy created.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: const Text('New Return Policy'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                    ...categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load categories: $e'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _returnWindowDays,
                decoration: const InputDecoration(labelText: 'Return Window (days) *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || int.tryParse(v.trim()) == null) ? 'Enter a whole number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _restockingFeePercent,
                decoration: const InputDecoration(labelText: 'Restocking Fee %'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || double.tryParse(v.trim()) == null) ? 'Enter a number' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
              ],
            ],
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
