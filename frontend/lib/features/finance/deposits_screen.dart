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
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../customers/customers_provider.dart';
import '../proforma/proforma_model.dart';
import '../proforma/proformas_provider.dart';
import 'deposit_model.dart';
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

  /// After a deposit is recorded, checks whether the customer's available balance now covers any
  /// of their still-Open proformas' outstanding amount and, if so, offers to convert them straight
  /// to a Sales Invoice — the same deposit>=total rule QuotationsController.Convert already applies,
  /// just triggered from the payment side instead of only being discoverable from the Proformas screen.
  Future<void> _checkProformaConversion(String customerId) async {
    final api = ref.read(apiClientProvider);

    final summaryResult = await api.get<DepositSummary?>(
      '/api/customers/$customerId/deposit-summary',
      (json) => DepositSummary.fromJson(json as Map<String, dynamic>),
    );
    final proformasResult = await api.get<List<Proforma>>(
      '/api/proformas',
      (json) => (json as List).map((e) => Proforma.fromJson(e as Map<String, dynamic>)).toList(),
      query: {'customerId': customerId},
    );

    if (!mounted) return;

    final available = switch (summaryResult) {
      ApiSuccess(data: final data) => data?.available ?? 0,
      _ => 0.0,
    };
    final proformas = switch (proformasResult) {
      ApiSuccess(data: final data) => data,
      _ => const <Proforma>[],
    };

    final eligible = proformas
        .where((p) => p.status == ProformaStatus.open && p.outstandingTotal > 0 && available >= p.outstandingTotal)
        .toList();
    if (eligible.isEmpty) return;

    showDialog(context: context, builder: (_) => _ProformaConversionPromptDialog(customerId: customerId, proformas: eligible));
  }

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
            onSaved: _checkProformaConversion,
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
                subtitle: 'Payments received, available to allocate against proformas and invoices',
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
  final void Function(String customerId)? onSaved;
  const _RecordDepositDialog({this.preselectedCustomerId, this.onSaved});

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
        final customerId = _customerId!;
        Navigator.of(context).pop();
        widget.onSaved?.call(customerId);
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

/// Shown right after a deposit is recorded, when it turns out to fully cover one or more of the
/// customer's still-Open proformas. Converting here is "allocate the now-available deposit, then
/// clear dues" in one step — the same two calls the Proformas screen would otherwise require the
/// admin to make manually (allocate-deposit, then convert) after noticing it themselves.
class _ProformaConversionPromptDialog extends ConsumerStatefulWidget {
  final String customerId;
  final List<Proforma> proformas;
  const _ProformaConversionPromptDialog({required this.customerId, required this.proformas});

  @override
  ConsumerState<_ProformaConversionPromptDialog> createState() => _ProformaConversionPromptDialogState();
}

class _ProformaConversionPromptDialogState extends ConsumerState<_ProformaConversionPromptDialog> {
  final _converting = <String>{};
  final _converted = <String>{};

  Future<void> _convert(Proforma p) async {
    setState(() => _converting.add(p.id));

    final api = ref.read(apiClientProvider);
    final allocateResult = await api.post<Map<String, dynamic>>(
      '/api/proformas/${p.id}/allocate-deposit',
      (json) => json as Map<String, dynamic>,
      body: const {'amount': null},
      idempotencyKey: api.newIdempotencyKey(),
    );

    if (allocateResult is! ApiSuccess) {
      if (!mounted) return;
      setState(() => _converting.remove(p.id));
      AppToast.error(switch (allocateResult) {
        ApiFailure(message: final msg) => msg,
        ApiNetworkError(message: final msg) => 'Could not reach the Host: $msg',
        _ => 'Could not allocate the deposit.',
      });
      return;
    }

    final convertResult = await api.post<Map<String, dynamic>>(
      '/api/proformas/${p.id}/convert',
      (json) => json as Map<String, dynamic>,
      body: const {},
      idempotencyKey: api.newIdempotencyKey(),
    );

    if (!mounted) return;
    setState(() => _converting.remove(p.id));

    switch (convertResult) {
      case ApiSuccess():
        setState(() => _converted.add(p.id));
        ref.invalidate(depositSummaryProvider(widget.customerId));
        ref.invalidate(proformasProvider);
        ref.invalidate(proformasByCustomerProvider(widget.customerId));
        AppToast.success('${p.proformaNumber} converted to a Sales Invoice.');
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Outstanding proforma now covered'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This customer\'s available deposit now covers the following proforma(s). Convert to a Sales Invoice?'),
            const SizedBox(height: 12),
            ...widget.proformas.map((p) {
              final isConverting = _converting.contains(p.id);
              final isConverted = _converted.contains(p.id);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.proformaNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Outstanding: ₹${p.outstandingTotal.toStringAsFixed(2)} of ₹${p.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: AppPalette.textSecondary)),
                        ],
                      ),
                    ),
                    if (isConverted)
                      const Icon(Icons.check_circle, color: AppPalette.success)
                    else
                      FilledButton(
                        onPressed: isConverting ? null : () => _convert(p),
                        child: isConverting
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Convert'),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
