import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../customers/customers_provider.dart';
import 'deposits_provider.dart';

const _pageSize = 20;

class DepositsScreen extends ConsumerStatefulWidget {
  const DepositsScreen({super.key});

  @override
  ConsumerState<DepositsScreen> createState() => _DepositsScreenState();
}

class _DepositsScreenState extends ConsumerState<DepositsScreen> {
  String? _selectedCustomerId;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final depositsAsync = ref.watch(depositsProvider(_selectedCustomerId));
    final nameOf = {for (final c in customersAsync.valueOrNull ?? []) c.id: c.name};

    void refresh() {
      ref.invalidate(depositsProvider);
      if (_selectedCustomerId != null) ref.invalidate(depositSummaryProvider(_selectedCustomerId!));
    }

    void openCreate() => showDialog(
          context: context,
          builder: (_) => _RecordDepositDialog(
            preselectedCustomerId: _selectedCustomerId,
          ),
        );

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: openCreate,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'Record Deposit (Ctrl+N)', label: 'Record Deposit'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Customer Deposits',
                subtitle: 'Payments received, available to allocate against invoices',
                actions: [
                  customersAsync.when(
                    data: (customers) => SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedCustomerId,
                        isDense: true,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, labelText: 'Filter by customer'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All customers')),
                          ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedCustomerId = v;
                          _page = 0;
                        }),
                      ),
                    ),
                    loading: () => const SizedBox(width: 240, child: LinearProgressIndicator()),
                    error: (_, _) => const Text('Could not load customers.'),
                  ),
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              if (_selectedCustomerId != null) ...[
                const SizedBox(height: 16),
                _SummaryCard(customerId: _selectedCustomerId!),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: depositsAsync.when(
                  data: (deposits) => AppListCard(
                    emptyMessage: 'No deposits yet.',
                    emptyIcon: Icons.savings_outlined,
                    columns: const [
                      AppListColumn('Customer', flex: 3),
                      AppListColumn('Amount', flex: 2),
                      AppListColumn('Payment Method', flex: 2),
                      AppListColumn('Date', flex: 3),
                    ],
                    itemCount: deposits.length,
                    itemsPerPage: _pageSize,
                    currentPage: _page,
                    onPageChange: (p) => setState(() => _page = p),
                    cellsBuilder: (context, i) {
                      final d = deposits[i];
                      return [
                        Text(nameOf[d.customerId] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('₹${d.amount.toStringAsFixed(2)}', style: const TextStyle(color: AppPalette.success, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(d.paymentMethod ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        Text(d.createdAt.toLocal().toString(), style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                      ];
                    },
                  ),
                  loading: () => Card(child: SkeletonTableRows(columns: 4)),
                  error: (e, _) => Center(child: Text('Failed to load deposits: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  final String customerId;
  const _SummaryCard({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(depositSummaryProvider(customerId));

    return summaryAsync.when(
      data: (s) => s == null
          ? const SizedBox.shrink()
          : Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('Deposited', s.totalDeposited),
                    _stat('Allocated', s.totalAllocated),
                    _stat('Available', s.available),
                  ],
                ),
              ),
            ),
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _stat(String label, double value) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );
}

class _RecordDepositDialog extends ConsumerStatefulWidget {
  final String? preselectedCustomerId;
  const _RecordDepositDialog({this.preselectedCustomerId});

  @override
  ConsumerState<_RecordDepositDialog> createState() => _RecordDepositDialogState();
}

class _RecordDepositDialogState extends ConsumerState<_RecordDepositDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _customerId;
  final _amount = TextEditingController();
  final _method = TextEditingController(text: 'cash');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _customerId = widget.preselectedCustomerId;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_customerId == null) {
      setState(() => _error = 'Select a customer.');
      return;
    }
    final amount = double.parse(_amount.text);

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/customer-deposits',
      (json) => json as Map<String, dynamic>,
      body: {
        'customerId': _customerId,
        'amount': amount,
        'paymentMethod': _method.text.trim().isEmpty ? null : _method.text.trim(),
        'notes': null,
      },
      idempotencyKey: api.newIdempotencyKey(),
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(depositsProvider);
        ref.invalidate(depositSummaryProvider(_customerId!));
        Navigator.of(context).pop();
      case ApiFailure(message: final msg):
        setState(() {
          _saving = false;
          _error = msg;
        });
      case ApiNetworkError(message: final msg):
        setState(() {
          _saving = false;
          _error = 'Could not reach the Host: $msg. It is safe to try again — this deposit was not '
              'recorded unless you see it appear after reconnecting.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return AlertDialog(
      title: const Text('Record Deposit'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            customersAsync.when(
              data: (customers) => SearchableDropdown<String>(
                label: 'Customer',
                value: _customerId,
                items: customers.map((c) => c.id).toList(),
                itemLabel: (id) => customers.firstWhere((c) => c.id == id).name,
                onChanged: (v) => setState(() => _customerId = v),
                validator: (v) => v == null ? 'Select a customer' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load customers.'),
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
            TextField(controller: _method, decoration: const InputDecoration(labelText: 'Payment Method')),
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

