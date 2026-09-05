import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format/quantity_format.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_button.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/reason_dialog.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../customers/customers_provider.dart';
import '../sales/sales_invoices_provider.dart';
import 'sales_return_model.dart';
import 'sales_returns_provider.dart';

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

Widget _returnStatusPill(SalesReturnStatus status) => switch (status) {
      SalesReturnStatus.requested => StatusPill.warning('Requested'),
      SalesReturnStatus.approved => StatusPill.info('Approved'),
      SalesReturnStatus.rejected => StatusPill.error('Rejected'),
      SalesReturnStatus.completed => StatusPill.success('Completed'),
      SalesReturnStatus.cancelled => StatusPill.cancelled('Cancelled'),
    };

class SalesReturnsScreen extends ConsumerStatefulWidget {
  const SalesReturnsScreen({super.key});

  @override
  ConsumerState<SalesReturnsScreen> createState() => _SalesReturnsScreenState();
}

class _SalesReturnsScreenState extends ConsumerState<SalesReturnsScreen> {
  String? _selectedId;
  final _search = TextEditingController();
  SalesReturnStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final returnsAsync = ref.watch(salesReturnsProvider);
    final customersAsync = ref.watch(customersProvider);
    final auth = ref.watch(authControllerProvider);
    final canApprove = auth.has(Permissions.salesReturnsApprove);
    void openCreate() => showDialog(context: context, builder: (_) => const _RequestReturnDialog());

    return ListScreenShortcuts(
      onRefresh: () => ref.invalidate(salesReturnsProvider),
      onNew: openCreate,
      child: Scaffold(
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'Request Return (Ctrl+N)', label: 'Request Return'),
        body: returnsAsync.when(
          data: (returns) {
            final customers = customersAsync.valueOrNull ?? [];
            final nameOf = {for (final c in customers) c.id: c.name};

            var filtered = returns;
            if (_statusFilter != null) filtered = filtered.where((r) => r.status == _statusFilter).toList();
            final query = _search.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              filtered = filtered
                  .where((r) => r.returnNumber.toLowerCase().contains(query) || (nameOf[r.customerId] ?? '').toLowerCase().contains(query))
                  .toList();
            }

            final selected = filtered.where((r) => r.id == _selectedId).firstOrNull;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Sales Returns',
                    subtitle: 'Customer returns awaiting approval, and their refund status',
                    actions: [
                      SizedBox(
                        width: 240,
                        height: 40,
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search returns...'),
                        ),
                      ),
                      FilterButton<SalesReturnStatus>(
                        value: _statusFilter,
                        allLabel: 'All Statuses',
                        options: SalesReturnStatus.values,
                        labelOf: (s) => s.name,
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(salesReturnsProvider),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No returns found.'))
                        : selected == null
                            ? _ReturnListCard(
                                returns: filtered,
                                nameOf: nameOf,
                                selectedId: null,
                                onSelect: (id) => setState(() => _selectedId = id),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _ReturnListCard(
                                      returns: filtered,
                                      nameOf: nameOf,
                                      selectedId: selected.id,
                                      onSelect: (id) => setState(() => _selectedId = id),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _ReturnDetailPanel(salesReturn: selected, customerName: nameOf[selected.customerId] ?? '-', canApprove: canApprove),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            );
          },
          loading: () => Padding(padding: const EdgeInsets.all(24), child: Card(child: SkeletonTableRows(columns: 5))),
          error: (e, _) => Center(child: Text('Failed to load returns: $e')),
        ),
      ),
    );
  }
}

class _ReturnListCard extends StatelessWidget {
  final List<SalesReturn> returns;
  final Map<String, String> nameOf;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _ReturnListCard({required this.returns, required this.nameOf, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      emptyMessage: 'No sales returns found.',
      emptyIcon: Icons.assignment_return_outlined,
      columns: const [
        AppListColumn('Doc No.', flex: 3),
        AppListColumn('Customer', flex: 4),
        AppListColumn('Date', flex: 3),
        AppListColumn('Refund', flex: 2),
        AppListColumn('Status', flex: 3),
      ],
      itemCount: returns.length,
      isSelected: (i) => returns[i].id == selectedId,
      onRowTap: (i) => onSelect(returns[i].id),
      cellsBuilder: (context, i) {
        final r = returns[i];
        return [
          Text(r.returnNumber, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(nameOf[r.customerId] ?? '-', style: const TextStyle(fontSize: 13)),
          Text(_formatDate(r.createdAt), style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
          Text('₹${r.totalRefundAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          _returnStatusPill(r.status),
        ];
      },
    );
  }
}

class _ReturnDetailPanel extends ConsumerStatefulWidget {
  final SalesReturn salesReturn;
  final String customerName;
  final bool canApprove;
  const _ReturnDetailPanel({required this.salesReturn, required this.customerName, required this.canApprove});

  @override
  ConsumerState<_ReturnDetailPanel> createState() => _ReturnDetailPanelState();
}

class _ReturnDetailPanelState extends ConsumerState<_ReturnDetailPanel> {
  bool _busy = false;

  Future<void> _act(Future<ApiResult<void>> Function() call) async {
    setState(() => _busy = true);
    final result = await call();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(salesReturnsProvider);
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  Future<void> _approve() async {
    final api = ref.read(apiClientProvider);
    await _act(() => api.post('/api/sales-returns/${widget.salesReturn.id}/approve', (_) {}));
  }

  Future<void> _reject() async {
    final reason = await showReasonDialog(context, title: 'Reject Return');
    if (reason == null) return;
    final api = ref.read(apiClientProvider);
    await _act(() => api.post('/api/sales-returns/${widget.salesReturn.id}/reject', (_) {}, body: {'reason': reason}));
  }

  Future<void> _complete() async {
    final method = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Refund Method'),
        content: const Text('How should this refund be issued?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(0), child: const Text('Cash (Amount Out)')),
          TextButton(onPressed: () => Navigator.of(context).pop(1), child: const Text('Credit to Deposit')),
        ],
      ),
    );
    if (method == null) return;

    final api = ref.read(apiClientProvider);
    await _act(() => api.post('/api/sales-returns/${widget.salesReturn.id}/complete', (_) {}, body: {'refundMethod': method}));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.salesReturn;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.returnNumber, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
                      const SizedBox(height: 2),
                      Text('${widget.customerName} · ${_formatDate(r.createdAt)}', style: TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
                      if (r.reason != null) ...[
                        const SizedBox(height: 2),
                        Text('Reason: ${r.reason}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
                _returnStatusPill(r.status),
              ],
            ),
            const SizedBox(height: 16),
            DefaultTextStyle(
              style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppPalette.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4),
              child: const Row(
                children: [
                  Expanded(flex: 5, child: Text('LINE')),
                  Expanded(flex: 2, child: Text('QTY')),
                  Expanded(flex: 2, child: Text('RESTOCK')),
                  Expanded(flex: 2, child: Text('REFUND')),
                ],
              ),
            ),
            const Divider(height: 16),
            ...r.lines.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: Text(l.description, style: const TextStyle(fontSize: 13))),
                      Expanded(flex: 2, child: Text(l.quantityReturned.toStringAsFixed(l.quantityReturned.truncateToDouble() == l.quantityReturned ? 0 : 2))),
                      Expanded(flex: 2, child: Text(l.restock ? 'Yes' : 'No')),
                      Expanded(flex: 2, child: Text('₹${l.refundAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Refund', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${r.totalRefundAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.canApprove && r.status == SalesReturnStatus.requested) ...[
                    OutlinedButton(onPressed: _approve, child: const Text('Approve')),
                    OutlinedButton(
                      onPressed: _reject,
                      style: OutlinedButton.styleFrom(foregroundColor: AppPalette.error, side: const BorderSide(color: AppPalette.error)),
                      child: const Text('Reject'),
                    ),
                  ],
                  if (widget.canApprove && r.status == SalesReturnStatus.approved)
                    FilledButton(onPressed: _complete, child: const Text('Complete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestReturnDialog extends ConsumerStatefulWidget {
  const _RequestReturnDialog();

  @override
  ConsumerState<_RequestReturnDialog> createState() => _RequestReturnDialogState();
}

class _LineSelection {
  final Map<String, dynamic> line;
  bool selected = false;
  bool restock = true;
  double quantity;
  _LineSelection(this.line) : quantity = (line['quantity'] as num).toDouble();
}

class _RequestReturnDialogState extends ConsumerState<_RequestReturnDialog> {
  String? _invoiceId;
  List<_LineSelection>? _lineSelections;
  final _reason = TextEditingController();
  bool _loadingLines = false;
  bool _saving = false;
  String? _error;

  Future<void> _loadInvoiceLines(String invoiceId) async {
    setState(() {
      _loadingLines = true;
      _lineSelections = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.get<Map<String, dynamic>>('/api/sales-invoices/$invoiceId', (json) => json as Map<String, dynamic>);

    if (!mounted) return;
    setState(() {
      _loadingLines = false;
      if (result is ApiSuccess<Map<String, dynamic>>) {
        _lineSelections = (result.data['lines'] as List).map((l) => _LineSelection(l as Map<String, dynamic>)).toList();
      }
    });
  }

  Future<void> _save() async {
    final selected = _lineSelections?.where((l) => l.selected).toList() ?? [];
    if (_invoiceId == null || selected.isEmpty || _reason.text.trim().isEmpty) {
      setState(() => _error = 'Select an invoice, at least one line, and enter a reason.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/sales-returns',
      (json) => json as Map<String, dynamic>,
      body: {
        'salesInvoiceId': _invoiceId,
        'reason': _reason.text.trim(),
        'lines': selected
            .map((l) => {
                  'salesInvoiceLineId': l.line['id'],
                  'quantityReturned': l.quantity,
                  'restock': l.restock,
                })
            .toList(),
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(salesReturnsProvider);
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
    final invoicesAsync = ref.watch(salesInvoicesProvider);

    return AlertDialog(
      title: const Text('Request Return'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              invoicesAsync.when(
                data: (invoices) => DropdownButtonFormField<String>(
                  initialValue: _invoiceId,
                  decoration: const InputDecoration(labelText: 'Sales Invoice'),
                  items: invoices.map((i) => DropdownMenuItem(value: i.id, child: Text(i.invoiceNumber))).toList(),
                  onChanged: (v) {
                    setState(() => _invoiceId = v);
                    if (v != null) _loadInvoiceLines(v);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load invoices.'),
              ),
              const SizedBox(height: 12),
              if (_loadingLines) const LinearProgressIndicator(),
              if (_lineSelections != null)
                ..._lineSelections!.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => setState(() => l.selected = !l.selected),
                            child: Row(
                              children: [
                                Checkbox(value: l.selected, onChanged: (v) => setState(() => l.selected = v ?? false)),
                                Expanded(child: Text('${l.line['description']} (qty ${l.line['quantity']})')),
                              ],
                            ),
                          ),
                          if (l.selected)
                            Padding(
                              padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: formatQuantity(l.quantity),
                                      decoration: const InputDecoration(labelText: 'Return qty', isDense: true),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                      onChanged: (v) => l.quantity = double.tryParse(v) ?? l.quantity,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(value: l.restock, onChanged: (v) => setState(() => l.restock = v ?? true)),
                                      const Text('Restock'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )),
              const SizedBox(height: 8),
              TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason')),
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
