import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
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
import '../items/brands_provider.dart';
import '../items/items_provider.dart';
import '../reports/document_payment_status.dart';
import '../users/user_directory_provider.dart';
import 'create_sales_invoice_dialog.dart';
import 'sales_invoice_model.dart';
import 'sales_invoices_provider.dart';

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

Widget _invoiceStatusPill(SalesInvoiceStatus status) =>
    status == SalesInvoiceStatus.active ? StatusPill.success('Active') : StatusPill.cancelled('Cancelled');

Widget _invoicePaymentStatusPill(DocumentPaymentStatus status) => switch (status) {
      DocumentPaymentStatus.paid => StatusPill.success(status.label),
      DocumentPaymentStatus.partiallyPaid => StatusPill.warning(status.label),
      DocumentPaymentStatus.credit => StatusPill.info(status.label),
      DocumentPaymentStatus.overdue => StatusPill.error(status.label),
    };

/// The Sales List tab of a Category's workspace (see CategoryWorkspaceScreen) — every invoice
/// shown here belongs to [categoryId], with the full filter set the backend supports (customer,
/// brand, status, payment status, date range, search, overdue-only).
class SalesInvoicesScreen extends ConsumerStatefulWidget {
  final String categoryId;
  const SalesInvoicesScreen({super.key, required this.categoryId});

  @override
  ConsumerState<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends ConsumerState<SalesInvoicesScreen> {
  String? _selectedId;
  final _search = TextEditingController();
  SalesInvoiceStatus? _statusFilter;
  DocumentPaymentStatus? _paymentFilter;
  String? _customerFilter;
  String? _brandFilter;
  DateTime? _from;
  DateTime? _to;
  bool _overdueOnly = false;

  SalesListFilter get _filter => SalesListFilter(
        categoryId: widget.categoryId,
        customerId: _customerFilter,
        brandId: _brandFilter,
        status: _statusFilter,
        paymentStatus: _paymentFilter,
        from: _from,
        to: _to,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        overdueOnly: _overdueOnly,
      );

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _from != null && _to != null ? DateTimeRange(start: _from!, end: _to!) : null,
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    final invoicesAsync = ref.watch(salesInvoicesFilteredProvider(filter));
    final customersAsync = ref.watch(customersProvider);
    final brandsAsync = ref.watch(brandsProvider(widget.categoryId));
    final usersAsync = ref.watch(userDirectoryProvider);
    final auth = ref.watch(authControllerProvider);
    final canCancel = auth.has(Permissions.salesInvoicesCancel);
    void refresh() => ref.invalidate(salesInvoicesFilteredProvider(filter));
    void openCreate() => showDialog(context: context, builder: (_) => CreateSalesInvoiceDialog(categoryId: widget.categoryId));

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: openCreate,
      child: Scaffold(
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'New Sales Invoice (Ctrl+N)', label: 'New Sales Invoice'),
        body: invoicesAsync.when(
          data: (invoices) {
            final customers = customersAsync.valueOrNull ?? [];
            final brands = brandsAsync.valueOrNull ?? [];
            final nameOf = {for (final c in customers) c.id: c.name};
            final phoneOf = {for (final c in customers) c.id: c.contactNumber};
            final userNameOf = <String, String>{for (final u in usersAsync.valueOrNull ?? const []) u.id: u.fullName};

            final selected = invoices.where((i) => i.id == _selectedId).firstOrNull;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Sales List',
                    subtitle: 'Finalized sales — the record of what customers have been billed',
                    actions: [
                      SizedBox(
                        width: 200,
                        height: 40,
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search invoices...'),
                        ),
                      ),
                      FilterButton<String>(
                        value: _customerFilter,
                        allLabel: 'All Customers',
                        options: customers.map((c) => c.id).toList(),
                        labelOf: (id) => nameOf[id] ?? id,
                        onChanged: (v) => setState(() => _customerFilter = v),
                      ),
                      FilterButton<String>(
                        value: _brandFilter,
                        allLabel: 'All Brands',
                        options: brands.map((b) => b.id).toList(),
                        labelOf: (id) => brands.where((b) => b.id == id).firstOrNull?.name ?? id,
                        onChanged: (v) => setState(() => _brandFilter = v),
                      ),
                      FilterButton<SalesInvoiceStatus>(
                        value: _statusFilter,
                        allLabel: 'All Statuses',
                        options: SalesInvoiceStatus.values,
                        labelOf: (s) => s.name,
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      FilterButton<DocumentPaymentStatus>(
                        value: _paymentFilter,
                        allLabel: 'All Payments',
                        options: DocumentPaymentStatus.values,
                        labelOf: (s) => s.label,
                        onChanged: (v) => setState(() => _paymentFilter = v),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(_from == null ? 'Date Range' : '${_from!.day}/${_from!.month} - ${_to!.day}/${_to!.month}'),
                      ),
                      FilterChip(
                        label: const Text('Overdue only'),
                        selected: _overdueOnly,
                        onSelected: (v) => setState(() => _overdueOnly = v),
                      ),
                      OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: invoices.isEmpty
                        ? const Center(child: Text('No sales invoices found.'))
                        : selected == null
                            ? _InvoiceListCard(
                                invoices: invoices,
                                nameOf: nameOf,
                                userNameOf: userNameOf,
                                selectedId: null,
                                onSelect: (id) => setState(() => _selectedId = id),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _InvoiceListCard(
                                      invoices: invoices,
                                      nameOf: nameOf,
                                      userNameOf: userNameOf,
                                      selectedId: selected.id,
                                      onSelect: (id) => setState(() => _selectedId = id),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _InvoiceDetailPanel(
                                      invoice: selected,
                                      customerName: nameOf[selected.customerId] ?? '-',
                                      customerPhone: phoneOf[selected.customerId],
                                      canCancel: canCancel,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            );
          },
          loading: () => Padding(padding: const EdgeInsets.all(24), child: Card(child: SkeletonTableRows(columns: 7))),
          error: (e, _) => Center(child: Text('Failed to load sales invoices: $e')),
        ),
      ),
    );
  }
}

class _InvoiceListCard extends StatelessWidget {
  final List<SalesInvoice> invoices;
  final Map<String, String> nameOf;
  final Map<String, String> userNameOf;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _InvoiceListCard({required this.invoices, required this.nameOf, required this.userNameOf, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      emptyMessage: 'No sales invoices found.',
      emptyIcon: Icons.receipt_long_outlined,
      columns: const [
        AppListColumn('Doc No.', flex: 3),
        AppListColumn('Customer', flex: 4),
        AppListColumn('Date', flex: 3),
        AppListColumn('Total', flex: 2),
        AppListColumn('Status', flex: 3),
        AppListColumn('Payment', flex: 3),
        AppListColumn('Created By', flex: 3),
      ],
      itemCount: invoices.length,
      isSelected: (i) => invoices[i].id == selectedId,
      onRowTap: (i) => onSelect(invoices[i].id),
      cellsBuilder: (context, i) {
        final inv = invoices[i];
        return [
          Text(inv.invoiceNumber, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(nameOf[inv.customerId] ?? '-', style: const TextStyle(fontSize: 13)),
          Text(_formatDate(inv.createdAt), style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
          Text('₹${inv.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          _invoiceStatusPill(inv.status),
          _invoicePaymentStatusPill(inv.paymentStatus),
          Text(userNameOf[inv.createdBy] ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
        ];
      },
    );
  }
}

class _InvoiceDetailPanel extends ConsumerStatefulWidget {
  final SalesInvoice invoice;
  final String customerName;
  final String? customerPhone;
  final bool canCancel;
  const _InvoiceDetailPanel({required this.invoice, required this.customerName, this.customerPhone, required this.canCancel});

  @override
  ConsumerState<_InvoiceDetailPanel> createState() => _InvoiceDetailPanelState();
}

class _InvoiceDetailPanelState extends ConsumerState<_InvoiceDetailPanel> {
  bool _busy = false;

  Future<void> _cancel() async {
    final reason = await showReasonDialog(context, title: 'Cancel Sales Invoice');
    if (reason == null) return;

    setState(() => _busy = true);

    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/sales-invoices/${widget.invoice.id}/cancel', (_) {}, body: {'reason': reason});

    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(salesInvoicesProvider);
        ref.invalidate(salesInvoicesFilteredProvider);
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final items = ref.watch(itemsProvider).valueOrNull ?? [];
    final isActive = inv.status == SalesInvoiceStatus.active;
    final cgstTotal = inv.lines.fold<double>(0, (sum, l) => sum + l.cgst);
    final sgstTotal = inv.lines.fold<double>(0, (sum, l) => sum + l.sgst);
    final igstTotal = inv.lines.fold<double>(0, (sum, l) => sum + l.igst);

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
                      Text(inv.invoiceNumber, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
                      const SizedBox(height: 2),
                      Text('${widget.customerName} · ${_formatDate(inv.createdAt)}', style: TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
                      if (inv.placeOfSupply != null && inv.placeOfSupply!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Place of Supply: ${inv.placeOfSupply}', style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                      ],
                      if (inv.dueDate != null) ...[
                        const SizedBox(height: 2),
                        Text('Due: ${_formatDate(inv.dueDate!)}', style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                      ],
                      if (inv.cancellationReason != null) ...[
                        const SizedBox(height: 2),
                        Text('Cancelled: ${inv.cancellationReason}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _invoiceStatusPill(inv.status),
                  const SizedBox(height: 4),
                  _invoicePaymentStatusPill(inv.paymentStatus),
                  if (inv.outstandingTotal > 0) ...[
                    const SizedBox(height: 4),
                    Text('Outstanding: ₹${inv.outstandingTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppPalette.textSecondary)),
                  ],
                ]),
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
            ...inv.lines.map((l) {
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
                  _totalRow('Subtotal', inv.subtotal),
                  if (cgstTotal > 0) _totalRow('CGST', cgstTotal),
                  if (sgstTotal > 0) _totalRow('SGST', sgstTotal),
                  if (igstTotal > 0) _totalRow('IGST', igstTotal),
                  if (inv.overallDiscountAmount > 0) _totalRow('Discount', -inv.overallDiscountAmount),
                  if (inv.depositAllocatedTotal > 0) _totalRow('Deposit Applied', -inv.depositAllocatedTotal),
                  const Divider(height: 16),
                  _totalRow('Grand Total', inv.grandTotal, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                PdfButton(path: '/api/sales-invoices/${inv.id}/pdf', fileName: '${inv.invoiceNumber}.pdf'),
                WhatsappSendButton(messageType: 2, referenceType: 2, referenceId: inv.id, defaultRecipientNumber: widget.customerPhone),
                if (widget.canCancel && isActive)
                  _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : OutlinedButton(
                          onPressed: _cancel,
                          style: OutlinedButton.styleFrom(foregroundColor: AppPalette.error, side: const BorderSide(color: AppPalette.error)),
                          child: const Text('Cancel Invoice'),
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
