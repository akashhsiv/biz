import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'finance_model.dart';
import 'finance_provider.dart';

const _pageSize = 20;

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(shopBalanceProvider);
    final transactionsAsync = ref.watch(financialTransactionsProvider);

    void refresh() {
      ref.invalidate(shopBalanceProvider);
      ref.invalidate(financialTransactionsProvider);
    }

    void openCreateOut() => showDialog(context: context, builder: (_) => const _AmountDialog(direction: _AmountDirection.out));
    void openCreateIn() => showDialog(context: context, builder: (_) => const _AmountDialog(direction: _AmountDirection.inbound));

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: openCreateOut,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Finance',
                subtitle: 'Shop-level cash balance and transaction history',
                actions: [
                  FilledButton.tonalIcon(
                    onPressed: openCreateIn,
                    style: FilledButton.styleFrom(backgroundColor: AppPalette.successLight, foregroundColor: AppPalette.successText),
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('Amount In'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: openCreateOut,
                    style: FilledButton.styleFrom(backgroundColor: AppPalette.errorLight, foregroundColor: AppPalette.errorText),
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('Amount Out'),
                  ),
                  IconButton.outlined(onPressed: refresh, tooltip: 'Refresh (F5)', icon: const Icon(Icons.refresh, size: 18)),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: balanceAsync.when(
                    data: (balance) => Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Shop Balance', style: TextStyle(color: AppPalette.textMuted)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Set Current Balance',
                              onPressed: () => showDialog(context: context, builder: (_) => _SetBalanceDialog(currentBalance: balance ?? 0)),
                            ),
                          ],
                        ),
                        Text(
                          balance == null ? '—' : '₹${balance.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    loading: () => const SkeletonBox(width: 160, height: 28),
                    error: (e, _) => Text('Failed: $e'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: transactionsAsync.when(
                  data: (transactions) => AppListCard(
                    emptyMessage: 'No transactions yet.',
                    emptyIcon: Icons.account_balance_wallet_outlined,
                    columns: const [
                      AppListColumn('Type', flex: 2),
                      AppListColumn('Date', flex: 3),
                      AppListColumn('Reason', flex: 4),
                      AppListColumn('Amount', flex: 2),
                    ],
                    itemCount: transactions.length,
                    itemsPerPage: _pageSize,
                    currentPage: _page,
                    onPageChange: (p) => setState(() => _page = p),
                    cellsBuilder: (context, i) {
                      final t = transactions[i];
                      final isCredit = t.direction == 0;
                      return [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: isCredit ? AppPalette.success : Colors.red),
                            const SizedBox(width: 4),
                            Flexible(child: Text(transactionTypeNames[t.transactionType], style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                        Text(t.createdAt.toLocal().toString(), style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                        Text(t.reason ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        Text(
                          '${isCredit ? "+" : "-"}₹${t.amount.toStringAsFixed(2)}',
                          style: TextStyle(color: isCredit ? AppPalette.success : Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ];
                    },
                  ),
                  loading: () => Card(child: SkeletonTableRows(columns: 4)),
                  error: (e, _) => Center(child: Text('Failed to load transactions: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AmountDirection { inbound, out }

/// Shared dialog for both Amount In (shop-level cash received that isn't a customer deposit — e.g.
/// misc/other income) and Amount Out. Amount In here deliberately has no customer field: money tied
/// to a customer goes through Customer Deposits instead, which credits that customer's deposit pool.
class _AmountDialog extends ConsumerStatefulWidget {
  final _AmountDirection direction;
  const _AmountDialog({required this.direction});

  @override
  ConsumerState<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends ConsumerState<_AmountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amount.text);
    final isIn = widget.direction == _AmountDirection.inbound;

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      isIn ? '/api/amount-in' : '/api/amount-out',
      (json) => json as Map<String, dynamic>,
      body: {'amount': amount, 'reason': _reason.text.trim()},
      idempotencyKey: api.newIdempotencyKey(),
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(shopBalanceProvider);
        ref.invalidate(financialTransactionsProvider);
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
    final isIn = widget.direction == _AmountDirection.inbound;
    return AlertDialog(
      title: Text(isIn ? 'Record Amount In' : 'Record Amount Out'),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

/// Lets the Shop Admin reconcile the computed shop balance against the real bank/cash balance —
/// intentionally has no customer field (this is a shop-level correction, not a customer transaction).
/// Under the hood it just posts a single Adjustment ledger entry for the difference; the balance
/// itself is never a directly-editable field (see FinanceLedgerService.GetShopBalanceAsync).
class _SetBalanceDialog extends ConsumerStatefulWidget {
  final double currentBalance;
  const _SetBalanceDialog({required this.currentBalance});

  @override
  ConsumerState<_SetBalanceDialog> createState() => _SetBalanceDialogState();
}

class _SetBalanceDialogState extends ConsumerState<_SetBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _targetBalance = TextEditingController(text: widget.currentBalance.toStringAsFixed(2));
  final _reason = TextEditingController(text: 'Reconciling with actual bank/cash balance');
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final target = double.parse(_targetBalance.text);

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/finance/set-balance',
      (json) => json as Map<String, dynamic>,
      body: {'targetBalance': target, 'reason': _reason.text.trim()},
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(shopBalanceProvider);
        ref.invalidate(financialTransactionsProvider);
        AppToast.success('Balance updated.');
        Navigator.of(context).pop();
      case ApiFailure(statusCode: 409, message: final msg):
        // "Nothing to adjust" isn't really a failure - the requested balance already matches.
        setState(() => _saving = false);
        AppToast.info(msg);
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
      title: const Text('Set Current Balance'),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current computed balance: ₹${widget.currentBalance.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetBalance,
                decoration: const InputDecoration(labelText: 'New Balance *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => double.tryParse(v ?? '') == null ? 'Enter a valid amount' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
              ),
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
