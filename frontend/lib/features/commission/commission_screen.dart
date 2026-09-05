import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../customers/customer_model.dart';
import '../customers/customers_provider.dart';
import '../items/item_model.dart';
import '../items/items_provider.dart';
import 'commission_model.dart';
import 'commission_provider.dart';

const _pageSize = 20;

class CommissionScreen extends StatelessWidget {
  const CommissionScreen({super.key});

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
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppPalette.primary,
                unselectedLabelColor: AppPalette.textSecondary,
                indicatorColor: AppPalette.primary,
                tabs: [Tab(text: 'Customer Rates'), Tab(text: 'Commission Entries')],
              ),
            ),
            const Expanded(child: TabBarView(children: [_CustomerRatesTab(), _CommissionEntriesTab()])),
          ],
        ),
      ),
    );
  }
}

// ---------- Customer Rates ----------

class _CustomerRatesTab extends ConsumerStatefulWidget {
  const _CustomerRatesTab();

  @override
  ConsumerState<_CustomerRatesTab> createState() => _CustomerRatesTabState();
}

class _CustomerRatesTabState extends ConsumerState<_CustomerRatesTab> {
  int _page = 0;
  bool _includeInactive = false;

  CustomerRateFilter get _filter => (customerId: null, includeInactive: _includeInactive);

  void _showCreateDialog() {
    showDialog(context: context, builder: (_) => const _RateFormDialog());
  }

  void _showEditDialog(CustomerProductRate rate) {
    showDialog(context: context, builder: (_) => _RateFormDialog(rate: rate));
  }

  Future<void> _deactivate(CustomerProductRate rate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Rate'),
        content: Text('Deactivate the commission rate for ${rate.customerName} / ${rate.itemName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/commission/customer-rates/${rate.id}/deactivate', (_) {});
    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(customerProductRatesProvider(_filter));
      case ApiFailure(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      case ApiNetworkError(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reach the Host: $msg')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.has(Permissions.commissionManage);
    final ratesAsync = ref.watch(customerProductRatesProvider(_filter));
    void refresh() => ref.invalidate(customerProductRatesProvider(_filter));

    return Scaffold(
      backgroundColor: AppPalette.surface,
      floatingActionButton: canManage
          ? AppFab(onPressed: _showCreateDialog, tooltip: 'New Rate', label: 'New Rate')
          : null,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Customer Commission Rates',
              subtitle: 'Special or commission rates configured per customer and item',
              actions: [
                FilterChip(
                  label: const Text('Show inactive'),
                  selected: _includeInactive,
                  onSelected: (v) => setState(() {
                    _includeInactive = v;
                    _page = 0;
                  }),
                ),
                OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ratesAsync.when(
                data: (rates) => AppListCard(
                  emptyMessage: 'No customer commission rates yet.',
                  emptyIcon: Icons.percent_outlined,
                  columns: const [
                    AppListColumn('Customer', flex: 3),
                    AppListColumn('Item', flex: 3),
                    AppListColumn('Special Rate', flex: 2, numeric: true),
                    AppListColumn('Commission Rate', flex: 2, numeric: true),
                    AppListColumn('Effective From', flex: 2),
                    AppListColumn('Status', flex: 2),
                    AppListColumn('Actions', flex: 2),
                  ],
                  itemCount: rates.length,
                  itemsPerPage: _pageSize,
                  currentPage: _page,
                  onPageChange: (p) => setState(() => _page = p),
                  cellsBuilder: (context, i) {
                    final r = rates[i];
                    return [
                      Text(r.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(r.itemName, style: const TextStyle(fontSize: 13)),
                      Text(r.specialRate?.toStringAsFixed(2) ?? '-', style: const TextStyle(fontSize: 13)),
                      Text(r.commissionRate?.toStringAsFixed(2) ?? '-', style: const TextStyle(fontSize: 13)),
                      Text(_formatDate(r.effectiveFrom), style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary)),
                      _ActiveBadge(isActive: r.isActive),
                      canManage
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit',
                                  onPressed: () => _showEditDialog(r),
                                ),
                                if (r.isActive)
                                  IconButton(
                                    icon: const Icon(Icons.block, size: 18),
                                    tooltip: 'Deactivate',
                                    onPressed: () => _deactivate(r),
                                  ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ];
                  },
                ),
                loading: () => Card(child: SkeletonTableRows(columns: 7)),
                error: (e, _) => Center(child: Text('Failed to load customer rates: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final bool isActive;
  const _ActiveBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _RateFormDialog extends ConsumerStatefulWidget {
  final CustomerProductRate? rate;
  const _RateFormDialog({this.rate});

  @override
  ConsumerState<_RateFormDialog> createState() => _RateFormDialogState();
}

class _RateFormDialogState extends ConsumerState<_RateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _specialRate = TextEditingController(text: widget.rate?.specialRate?.toStringAsFixed(2) ?? '');
  late final _commissionRate = TextEditingController(text: widget.rate?.commissionRate?.toStringAsFixed(2) ?? '');
  late DateTime _effectiveFrom = widget.rate?.effectiveFrom ?? DateTime.now();
  String? _customerId;
  String? _itemId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.rate != null;

  @override
  void initState() {
    super.initState();
    _customerId = widget.rate?.customerId;
    _itemId = widget.rate?.itemId;
  }

  @override
  void dispose() {
    _specialRate.dispose();
    _commissionRate.dispose();
    super.dispose();
  }

  Future<void> _pickEffectiveFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _effectiveFrom = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_customerId == null || _itemId == null) {
      setState(() => _error = 'Customer and item are required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final body = {
      'customerId': _customerId,
      'itemId': _itemId,
      'specialRate': _specialRate.text.trim().isEmpty ? null : double.tryParse(_specialRate.text.trim()),
      'commissionRate': _commissionRate.text.trim().isEmpty ? null : double.tryParse(_commissionRate.text.trim()),
      'effectiveFrom': _effectiveFrom.toIso8601String(),
    };

    final result = _isEdit
        ? await api.put<Map<String, dynamic>>('/api/commission/customer-rates/${widget.rate!.id}', (json) => json as Map<String, dynamic>, body: body)
        : await api.post<Map<String, dynamic>>('/api/commission/customer-rates', (json) => json as Map<String, dynamic>, body: body);

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(customerProductRatesProvider);
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
    final customersAsync = ref.watch(customersProvider);
    final itemsAsync = ref.watch(itemsProvider);

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Commission Rate' : 'New Commission Rate'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                customersAsync.when(
                  data: (customers) => DropdownButtonFormField<String>(
                    initialValue: _customerId,
                    decoration: const InputDecoration(labelText: 'Customer *'),
                    items: customers.map((Customer c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: _isEdit ? null : (v) => setState(() => _customerId = v),
                    validator: (v) => v == null ? 'Customer is required' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load customers: $e'),
                ),
                const SizedBox(height: 12),
                itemsAsync.when(
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: _itemId,
                    decoration: const InputDecoration(labelText: 'Item *'),
                    items: items.map((Item i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                    onChanged: _isEdit ? null : (v) => setState(() => _itemId = v),
                    validator: (v) => v == null ? 'Item is required' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Failed to load items: $e'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _specialRate,
                        decoration: const InputDecoration(labelText: 'Special Rate'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _commissionRate,
                        decoration: const InputDecoration(labelText: 'Commission Rate'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickEffectiveFrom,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Effective From'),
                    child: Text(_formatDate(_effectiveFrom)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
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

// ---------- Commission Entries ----------

class _CommissionEntriesTab extends ConsumerStatefulWidget {
  const _CommissionEntriesTab();

  @override
  ConsumerState<_CommissionEntriesTab> createState() => _CommissionEntriesTabState();
}

class _CommissionEntriesTabState extends ConsumerState<_CommissionEntriesTab> {
  int _page = 0;
  CommissionEntryStatus? _statusFilter;

  CommissionEntryFilter get _filter =>
      (customerId: null, status: _statusFilter, fromDate: null, toDate: null);

  void _pay(CommissionEntry entry) {
    showDialog(context: context, builder: (_) => _PayEntryDialog(entry: entry, filter: _filter));
  }

  Future<void> _cancel(CommissionEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Commission Entry'),
        content: Text('Cancel the commission entry for ${entry.customerName} / ${entry.itemName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel Entry')),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/commission/entries/${entry.id}/cancel', (_) {});
    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(commissionEntriesProvider(_filter));
      case ApiFailure(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      case ApiNetworkError(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reach the Host: $msg')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.has(Permissions.commissionManage);
    final entriesAsync = ref.watch(commissionEntriesProvider(_filter));
    void refresh() => ref.invalidate(commissionEntriesProvider(_filter));

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Commission Entries',
              subtitle: 'Commission earned per sales invoice line, and its payment status',
              actions: [
                SizedBox(
                  width: 200,
                  height: 40,
                  child: DropdownButtonFormField<CommissionEntryStatus?>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(isDense: true, labelText: 'Status'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All statuses')),
                      ...CommissionEntryStatus.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(commissionEntryStatusLabel(s)))),
                    ],
                    onChanged: (v) => setState(() {
                      _statusFilter = v;
                      _page = 0;
                    }),
                  ),
                ),
                OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: entriesAsync.when(
                data: (entries) => AppListCard(
                  emptyMessage: 'No commission entries yet.',
                  emptyIcon: Icons.request_quote_outlined,
                  columns: const [
                    AppListColumn('Customer', flex: 3),
                    AppListColumn('Item', flex: 3),
                    AppListColumn('Invoice', flex: 2),
                    AppListColumn('Amount', flex: 2, numeric: true),
                    AppListColumn('Paid', flex: 2, numeric: true),
                    AppListColumn('Status', flex: 2),
                    AppListColumn('Actions', flex: 2),
                  ],
                  itemCount: entries.length,
                  itemsPerPage: _pageSize,
                  currentPage: _page,
                  onPageChange: (p) => setState(() => _page = p),
                  cellsBuilder: (context, i) {
                    final e = entries[i];
                    final canAct = canManage && e.status != CommissionEntryStatus.paid && e.status != CommissionEntryStatus.cancelled;
                    return [
                      Text(e.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(e.itemName, style: const TextStyle(fontSize: 13)),
                      Text(e.invoiceNumber, style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary)),
                      Text(e.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 13)),
                      Text(e.paidAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary)),
                      _EntryStatusBadge(status: e.status),
                      canAct
                          ? Row(
                              children: [
                                OutlinedButton(onPressed: () => _pay(e), child: const Text('Pay')),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, size: 18),
                                  tooltip: 'Cancel',
                                  onPressed: () => _cancel(e),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ];
                  },
                ),
                loading: () => Card(child: SkeletonTableRows(columns: 7)),
                error: (e, _) => Center(child: Text('Failed to load commission entries: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryStatusBadge extends StatelessWidget {
  final CommissionEntryStatus status;
  const _EntryStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CommissionEntryStatus.paid => Colors.green,
      CommissionEntryStatus.partiallyPaid => Colors.orange,
      CommissionEntryStatus.pending => Colors.red,
      CommissionEntryStatus.cancelled => Colors.grey,
      CommissionEntryStatus.adjusted => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(commissionEntryStatusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _PayEntryDialog extends ConsumerStatefulWidget {
  final CommissionEntry entry;
  final CommissionEntryFilter filter;
  const _PayEntryDialog({required this.entry, required this.filter});

  @override
  ConsumerState<_PayEntryDialog> createState() => _PayEntryDialogState();
}

class _PayEntryDialogState extends ConsumerState<_PayEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.entry.pendingAmount.toStringAsFixed(2));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.entry.pendingAmount) {
      setState(() => _error = 'Amount must be between 0 and ${widget.entry.pendingAmount.toStringAsFixed(2)}.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/commission/entries/${widget.entry.id}/pay',
      (json) => json as Map<String, dynamic>,
      body: {'amount': amount},
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(commissionEntriesProvider(widget.filter));
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
      title: const Text('Record Commission Payment'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount: ${widget.entry.amount.toStringAsFixed(2)}  ·  Paid: ${widget.entry.paidAmount.toStringAsFixed(2)}  ·  Pending: ${widget.entry.pendingAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: AppPalette.textSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Amount is required' : null,
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

String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
