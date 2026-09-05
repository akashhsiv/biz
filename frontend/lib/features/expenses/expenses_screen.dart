import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../finance/finance_provider.dart';
import 'expense_model.dart';
import 'expenses_provider.dart';

const _pageSize = 20;

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _search = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    void refresh() => ref.invalidate(expensesProvider);
    void openCreate() => showDialog(context: context, builder: (_) => const _CreateExpenseDialog());

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: openCreate,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'New Expense (Ctrl+N)', label: 'New Expense'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Expenses',
                subtitle: 'Shop running costs — rent, utilities, and other outgoings',
                actions: [
                  SizedBox(
                    width: 240,
                    height: 40,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search expenses...'),
                    ),
                  ),
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: expensesAsync.when(
                  data: (expenses) {
                    final query = _search.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? expenses
                        : expenses.where((e) => e.category.toLowerCase().contains(query) || e.reason.toLowerCase().contains(query)).toList();

                    return AppListCard(
                      emptyMessage: query.isEmpty ? 'No expenses recorded yet.' : 'No expenses match "$query".',
                      emptyIcon: Icons.receipt_long_outlined,
                      columns: const [
                        AppListColumn('Category', flex: 2),
                        AppListColumn('Reason', flex: 3),
                        AppListColumn('Payment Method', flex: 2),
                        AppListColumn('Amount', flex: 2, numeric: true),
                        AppListColumn('Date', flex: 2),
                      ],
                      itemCount: filtered.length,
                      itemsPerPage: _pageSize,
                      currentPage: _page,
                      onPageChange: (p) => setState(() => _page = p),
                      cellsBuilder: (context, i) {
                        final e = filtered[i];
                        return [
                          Text(e.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(e.reason, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          Text(e.paymentMethod ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          Text('₹${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(e.createdAt.toLocal().toString().split('.').first, style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                        ];
                      },
                    );
                  },
                  loading: () => Card(child: SkeletonTableRows(columns: 5)),
                  error: (e, _) => Center(child: Text('Failed to load expenses: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateExpenseDialog extends ConsumerStatefulWidget {
  const _CreateExpenseDialog();

  @override
  ConsumerState<_CreateExpenseDialog> createState() => _CreateExpenseDialogState();
}

class _CreateExpenseDialogState extends ConsumerState<_CreateExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _category = TextEditingController();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _paymentMethod = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/expenses',
      (json) => json as Map<String, dynamic>,
      body: {
        'category': _category.text.trim(),
        'amount': double.tryParse(_amount.text) ?? 0,
        'reason': _reason.text.trim(),
        'paymentMethod': _paymentMethod.text.trim().isEmpty ? null : _paymentMethod.text.trim(),
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(expensesProvider);
        ref.invalidate(shopBalanceProvider);
        ref.invalidate(financialTransactionsProvider);
        AppToast.success('Expense recorded.');
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
      title: const Text('New Expense'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return commonExpenseCategories;
                  return commonExpenseCategories.where((c) => c.toLowerCase().contains(value.text.toLowerCase()));
                },
                onSelected: (selection) => _category.text = selection,
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  // Keep the Autocomplete's own internal controller in sync with `_category` so
                  // free-typed text (never selected from the suggestion list) is saved too.
                  controller.addListener(() => _category.text = controller.text);
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Category *', hintText: 'e.g. Rent, Electricity'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Category is required' : null,
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final amount = double.tryParse(v ?? '');
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
              ),
              const SizedBox(height: 8),
              TextField(controller: _paymentMethod, decoration: const InputDecoration(labelText: 'Payment Method')),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
