import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/network/idempotent_action_runner.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_button.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/pdf_button.dart';
import '../../shared/widgets/reason_dialog.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/whatsapp_send_button.dart';
import '../customers/customers_provider.dart';
import '../items/items_provider.dart';
import 'proforma_model.dart';
import 'proformas_provider.dart';

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Prompts for an optional due date (credit terms) before converting a Proforma to a Sales
/// Invoice — this is the actual invoice-creation step, so it's the natural place to set the
/// invoice's payment due date. Returns null if the user cancelled the whole conversion, or a
/// (possibly-null) DateTime if they proceeded — null meaning "no due date / due immediately".
Future<(bool proceed, DateTime? dueDate)> _promptDueDate(BuildContext context) async {
  DateTime? dueDate;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Convert to Sales Invoice'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Optionally set a due date to grant credit terms on the resulting invoice.'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => dueDate = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(dueDate == null ? 'Set Due Date (optional)' : 'Due: ${_formatDate(dueDate!)}'),
              ),
              if (dueDate != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () => setState(() => dueDate = null), child: const Text('Clear due date')),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Convert')),
        ],
      ),
    ),
  );
  return (proceed ?? false, dueDate);
}

Widget _proformaStatusPill(ProformaStatus status) => switch (status) {
      ProformaStatus.open => StatusPill.warning('Open'),
      ProformaStatus.fullyFunded => StatusPill.info('Fully Funded'),
      ProformaStatus.converted => StatusPill.converted('Converted'),
      ProformaStatus.cancelled => StatusPill.cancelled('Cancelled'),
    };

class ProformasScreen extends ConsumerStatefulWidget {
  const ProformasScreen({super.key});

  @override
  ConsumerState<ProformasScreen> createState() => _ProformasScreenState();
}

class _ProformasScreenState extends ConsumerState<ProformasScreen> {
  String? _selectedId;
  final _search = TextEditingController();
  ProformaStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final proformasAsync = ref.watch(proformasProvider);
    final customersAsync = ref.watch(customersProvider);

    return ListScreenShortcuts(
      onRefresh: () => ref.invalidate(proformasProvider),
      child: Scaffold(
        body: proformasAsync.when(
          data: (proformas) {
            final customers = customersAsync.valueOrNull ?? [];
            final nameOf = {for (final c in customers) c.id: c.name};
            final phoneOf = {for (final c in customers) c.id: c.contactNumber};

            var filtered = proformas;
            if (_statusFilter != null) filtered = filtered.where((p) => p.status == _statusFilter).toList();
            final query = _search.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              filtered = filtered
                  .where((p) => p.proformaNumber.toLowerCase().contains(query) || (nameOf[p.customerId] ?? '').toLowerCase().contains(query))
                  .toList();
            }

            final selected = filtered.where((p) => p.id == _selectedId).firstOrNull;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Proforma Invoices',
                    subtitle: 'Partially-funded orders awaiting the remaining balance',
                    actions: [
                      SizedBox(
                        width: 240,
                        height: 40,
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search proformas...'),
                        ),
                      ),
                      FilterButton<ProformaStatus>(
                        value: _statusFilter,
                        allLabel: 'All Statuses',
                        options: ProformaStatus.values,
                        labelOf: (s) => s.name,
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(proformasProvider),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No proformas found.'))
                        : selected == null
                            ? _ProformaListCard(
                                proformas: filtered,
                                nameOf: nameOf,
                                selectedId: null,
                                onSelect: (id) => setState(() => _selectedId = id),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _ProformaListCard(
                                      proformas: filtered,
                                      nameOf: nameOf,
                                      selectedId: selected.id,
                                      onSelect: (id) => setState(() => _selectedId = id),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _ProformaDetailPanel(
                                      proforma: selected,
                                      customerName: nameOf[selected.customerId] ?? '-',
                                      customerPhone: phoneOf[selected.customerId],
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            );
          },
          loading: () => Padding(padding: const EdgeInsets.all(24), child: Card(child: SkeletonTableRows(columns: 5))),
          error: (e, _) => Center(child: Text('Failed to load proformas: $e')),
        ),
      ),
    );
  }
}

class _ProformaListCard extends StatelessWidget {
  final List<Proforma> proformas;
  final Map<String, String> nameOf;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _ProformaListCard({required this.proformas, required this.nameOf, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      emptyMessage: 'No proforma invoices found.',
      emptyIcon: Icons.description_outlined,
      columns: const [
        AppListColumn('Doc No.', flex: 3),
        AppListColumn('Customer', flex: 4),
        AppListColumn('Date', flex: 3),
        AppListColumn('Total', flex: 2),
        AppListColumn('Status', flex: 3),
      ],
      itemCount: proformas.length,
      isSelected: (i) => proformas[i].id == selectedId,
      onRowTap: (i) => onSelect(proformas[i].id),
      cellsBuilder: (context, i) {
        final p = proformas[i];
        return [
          Text(p.proformaNumber, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(nameOf[p.customerId] ?? '-', style: const TextStyle(fontSize: 13)),
          Text(_formatDate(p.createdAt), style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
          Text('₹${p.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          _proformaStatusPill(p.status),
        ];
      },
    );
  }
}

class _ProformaDetailPanel extends ConsumerStatefulWidget {
  final Proforma proforma;
  final String customerName;
  final String? customerPhone;
  const _ProformaDetailPanel({required this.proforma, required this.customerName, this.customerPhone});

  @override
  ConsumerState<_ProformaDetailPanel> createState() => _ProformaDetailPanelState();
}

class _ProformaDetailPanelState extends ConsumerState<_ProformaDetailPanel> {
  bool _busy = false;
  String? _notice;

  Future<void> _allocateDeposit() async {
    setState(() {
      _busy = true;
      _notice = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await ref.read(idempotentActionRunnerProvider).run<Map<String, dynamic>>(
          actionId: 'allocate-${widget.proforma.id}',
          call: (key) => api.post(
            '/api/proformas/${widget.proforma.id}/allocate-deposit',
            (json) => json as Map<String, dynamic>,
            body: const {'amount': null},
            idempotencyKey: key,
          ),
        );

    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(proformasProvider);
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError():
        setState(() => _notice = "Connection lost — couldn't confirm the allocation. Retry is safe.");
    }
  }

  Future<void> _convert() async {
    final (proceed, dueDate) = await _promptDueDate(context);
    if (!proceed) return;

    setState(() {
      _busy = true;
      _notice = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await ref.read(idempotentActionRunnerProvider).run<Map<String, dynamic>>(
          actionId: 'convert-${widget.proforma.id}',
          call: (key) => api.post(
            '/api/proformas/${widget.proforma.id}/convert',
            (json) => json as Map<String, dynamic>,
            body: const {},
            idempotencyKey: key,
            query: {if (dueDate != null) 'dueDate': dueDate.toIso8601String()},
          ),
        );

    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case ApiSuccess(data: final data):
        ref.invalidate(proformasProvider);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Converted to Sales Invoice'),
            content: Text('Document: ${data['documentNumber']}\nGrand Total: ₹${(data['grandTotal'] as num).toStringAsFixed(2)}'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError():
        setState(() => _notice = "Connection lost — couldn't confirm the conversion. Retry is safe.");
    }
  }

  Future<void> _cancel() async {
    final reason = await showReasonDialog(context, title: 'Cancel Proforma');
    if (reason == null) return;

    setState(() => _busy = true);

    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/proformas/${widget.proforma.id}/cancel', (_) {}, body: {'reason': reason});

    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(proformasProvider);
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proforma;
    final items = ref.watch(itemsProvider).valueOrNull ?? [];
    final canAllocate = p.status == ProformaStatus.open && p.outstandingTotal > 0;
    final canConvert = p.outstandingTotal == 0 && p.status != ProformaStatus.converted && p.status != ProformaStatus.cancelled;
    final canCancel = p.status == ProformaStatus.open || p.status == ProformaStatus.fullyFunded;
    final cgstTotal = p.lines.fold<double>(0, (sum, l) => sum + l.cgst);
    final sgstTotal = p.lines.fold<double>(0, (sum, l) => sum + l.sgst);
    final igstTotal = p.lines.fold<double>(0, (sum, l) => sum + l.igst);

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
                      Text(p.proformaNumber, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
                      const SizedBox(height: 2),
                      Text('${widget.customerName} · ${_formatDate(p.createdAt)}', style: TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
                      if (p.placeOfSupply != null && p.placeOfSupply!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Place of Supply: ${p.placeOfSupply}', style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                _proformaStatusPill(p.status),
              ],
            ),
            const SizedBox(height: 16),
            DefaultTextStyle(
              style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppPalette.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: Text('ITEM')),
                  Expanded(flex: 2, child: Text('HSN')),
                  Expanded(flex: 2, child: Text('QTY')),
                  Expanded(flex: 2, child: Text('RATE')),
                  Expanded(flex: 2, child: Text('AMOUNT')),
                ],
              ),
            ),
            const Divider(height: 16),
            ...p.lines.map((l) {
              final item = l.itemId == null ? null : items.where((it) => it.id == l.itemId).firstOrNull;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(l.description, style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 2, child: Text(item?.hsnCode ?? '-', style: TextStyle(color: AppPalette.textMuted, fontSize: 12))),
                    Expanded(flex: 2, child: Text(l.quantity.toStringAsFixed(l.quantity.truncateToDouble() == l.quantity ? 0 : 2))),
                    Expanded(flex: 2, child: Text('₹${l.rate.toStringAsFixed(0)}')),
                    Expanded(flex: 2, child: Text('₹${l.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  _totalRow('Subtotal', p.subtotal),
                  if (cgstTotal > 0) _totalRow('CGST', cgstTotal),
                  if (sgstTotal > 0) _totalRow('SGST', sgstTotal),
                  if (igstTotal > 0) _totalRow('IGST', igstTotal),
                  if (p.overallDiscountAmount > 0) _totalRow('Discount', -p.overallDiscountAmount),
                  const Divider(height: 16),
                  _totalRow('Grand Total', p.grandTotal, bold: true),
                  _totalRow('Deposit Allocated', p.allocatedTotal),
                  _totalRow('Outstanding', p.outstandingTotal, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_notice!, style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
              ),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  PdfButton(path: '/api/proformas/${p.id}/pdf', fileName: '${p.proformaNumber}.pdf'),
                  WhatsappSendButton(messageType: 1, referenceType: 1, referenceId: p.id, defaultRecipientNumber: widget.customerPhone),
                  if (canAllocate) OutlinedButton(onPressed: _allocateDeposit, child: const Text('Allocate Deposit')),
                  if (canConvert) FilledButton(onPressed: _convert, child: const Text('Convert to Invoice')),
                  if (canCancel)
                    OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(foregroundColor: AppPalette.error, side: const BorderSide(color: AppPalette.error)),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 14 : 13)),
            Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 14 : 13)),
          ],
        ),
      );
}
