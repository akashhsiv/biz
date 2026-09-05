import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/format/quantity_format.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_button.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/pdf_button.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/whatsapp_send_button.dart';
import '../customers/customers_provider.dart';
import '../customers/customers_screen.dart';
import '../items/item_model.dart';
import '../items/items_provider.dart';
import '../users/user_directory_provider.dart';
import 'quotation_model.dart';
import 'quotations_provider.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  bool _creating = false;
  String? _selectedId;
  final _search = TextEditingController();
  QuotationStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    // Shown in place of the list, inside this tab's own content slot — not pushed onto the app's
    // root Navigator, which would cover AppShell's sidebar (that lives outside any per-tab routing;
    // switching tabs/pages here is just local state, same as every other module in this app).
    if (_creating) {
      return _CreateQuotationPage(onDone: () => setState(() => _creating = false));
    }

    final quotationsAsync = ref.watch(quotationsProvider);
    final customersAsync = ref.watch(customersProvider);
    final usersAsync = ref.watch(userDirectoryProvider);
    void openCreate() => setState(() => _creating = true);

    return ListScreenShortcuts(
      onRefresh: () => ref.invalidate(quotationsProvider),
      onNew: openCreate,
      child: Scaffold(
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'New Quotation (Ctrl+N)', label: 'New Quotation'),
        body: quotationsAsync.when(
          data: (quotations) {
            final customers = customersAsync.valueOrNull ?? [];
            final nameOf = {for (final c in customers) c.id: c.name};
            final phoneOf = {for (final c in customers) c.id: c.contactNumber};
            final userNameOf = <String, String>{for (final u in usersAsync.valueOrNull ?? const []) u.id: u.fullName};

            var filtered = quotations;
            if (_statusFilter != null) filtered = filtered.where((q) => q.status == _statusFilter).toList();
            final query = _search.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              filtered = filtered
                  .where((q) => q.quotationNumber.toLowerCase().contains(query) || (nameOf[q.customerId] ?? '').toLowerCase().contains(query))
                  .toList();
            }

            final selected = filtered.where((q) => q.id == _selectedId).firstOrNull;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Quotations',
                    subtitle: 'Price quotes sent to customers, ready to convert once accepted',
                    actions: [
                      SizedBox(
                        width: 240,
                        height: 40,
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            isDense: true,
                            prefixIcon: Icon(Icons.search, size: 18),
                            hintText: 'Search quotations...',
                          ),
                        ),
                      ),
                      FilterButton<QuotationStatus>(
                        value: _statusFilter,
                        allLabel: 'All Statuses',
                        options: QuotationStatus.values,
                        labelOf: (s) => s.name,
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(quotationsProvider),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No quotations found.'))
                        : selected == null
                            ? _QuotationListCard(
                                quotations: filtered,
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
                                    child: _QuotationListCard(
                                      quotations: filtered,
                                      nameOf: nameOf,
                                      userNameOf: userNameOf,
                                      selectedId: selected.id,
                                      onSelect: (id) => setState(() => _selectedId = id),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _QuotationDetailPanel(
                                      quotation: selected,
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
          loading: () => Padding(padding: const EdgeInsets.all(24), child: Card(child: SkeletonTableRows(columns: 6))),
          error: (e, _) => Center(child: Text('Failed to load quotations: $e')),
        ),
      ),
    );
  }
}

class _QuotationListCard extends StatelessWidget {
  final List<Quotation> quotations;
  final Map<String, String> nameOf;
  final Map<String, String> userNameOf;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _QuotationListCard({required this.quotations, required this.nameOf, required this.userNameOf, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      emptyMessage: 'No quotations found.',
      emptyIcon: Icons.request_quote_outlined,
      columns: const [
        AppListColumn('Doc No.', flex: 3),
        AppListColumn('Customer', flex: 4),
        AppListColumn('Date', flex: 3),
        AppListColumn('Total', flex: 2),
        AppListColumn('Status', flex: 3),
        AppListColumn('Created By', flex: 3),
      ],
      itemCount: quotations.length,
      isSelected: (i) => quotations[i].id == selectedId,
      onRowTap: (i) => onSelect(quotations[i].id),
      cellsBuilder: (context, i) {
        final q = quotations[i];
        return [
          Text(q.quotationNumber, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(nameOf[q.customerId] ?? '-', style: const TextStyle(fontSize: 13)),
          Text(_formatDate(q.createdAt), style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
          Text('₹${q.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          _quotationStatusPill(q.status),
          Text(userNameOf[q.createdBy] ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
        ];
      },
    );
  }
}

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _QuotationDetailPanel extends ConsumerStatefulWidget {
  final Quotation quotation;
  final String customerName;
  final String? customerPhone;
  const _QuotationDetailPanel({required this.quotation, required this.customerName, this.customerPhone});

  @override
  ConsumerState<_QuotationDetailPanel> createState() => _QuotationDetailPanelState();
}

class _QuotationDetailPanelState extends ConsumerState<_QuotationDetailPanel> {
  bool _converting = false;
  String? _unknownOutcomeMessage;

  Future<void> _convert() async {
    setState(() {
      _converting = true;
      _unknownOutcomeMessage = null;
    });

    final result = await ref.read(quotationConvertControllerProvider).convert(widget.quotation.id);
    if (!mounted) return;

    switch (result) {
      case ApiSuccess(data: final data):
        setState(() => _converting = false);
        ref.invalidate(quotationsProvider);
        _showResultDialog(data);
      case ApiFailure(message: final msg):
        setState(() => _converting = false);
        AppToast.error(msg);
      case ApiNetworkError():
        setState(() {
          _converting = false;
          _unknownOutcomeMessage = "Connection lost — we couldn't confirm this went through. "
              "It's safe to press Retry once you're reconnected; it will not double-charge.";
        });
    }
  }

  void _showResultDialog(ConvertResult result) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(result.resultType == 'SalesInvoice' ? 'Converted to Sales Invoice' : 'Converted to Proforma Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document: ${result.documentNumber}'),
            Text('Grand Total: ₹${result.grandTotal.toStringAsFixed(2)}'),
            Text('Deposit Applied: ₹${result.depositApplied.toStringAsFixed(2)}'),
            if (result.outstanding > 0) Text('Outstanding: ₹${result.outstanding.toStringAsFixed(2)}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final items = ref.watch(itemsProvider).valueOrNull ?? [];
    final canConvert = q.status == QuotationStatus.draft || q.status == QuotationStatus.issued;
    final cgstTotal = q.lines.fold<double>(0, (sum, l) => sum + l.cgst);
    final sgstTotal = q.lines.fold<double>(0, (sum, l) => sum + l.sgst);
    final igstTotal = q.lines.fold<double>(0, (sum, l) => sum + l.igst);

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
                      Text(q.quotationNumber, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
                      const SizedBox(height: 2),
                      Text('${widget.customerName} · ${_formatDate(q.createdAt)}', style: TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
                      if (q.placeOfSupply != null && q.placeOfSupply!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Place of Supply: ${q.placeOfSupply}', style: const TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                _quotationStatusPill(q.status),
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
            ...q.lines.map((l) {
              final item = l.itemId == null ? null : items.where((it) => it.id == l.itemId).firstOrNull;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(l.description, style: const TextStyle(fontSize: 13)),
                    ),
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
                  _totalRow('Subtotal', q.subtotal),
                  if (cgstTotal > 0) _totalRow('CGST', cgstTotal),
                  if (sgstTotal > 0) _totalRow('SGST', sgstTotal),
                  if (igstTotal > 0) _totalRow('IGST', igstTotal),
                  if (q.overallDiscountAmount > 0) _totalRow('Discount', -q.overallDiscountAmount),
                  const Divider(height: 16),
                  _totalRow('Grand Total', q.grandTotal, bold: true),
                ],
              ),
            ),
            if (q.notes != null && q.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Notes', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppPalette.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(q.notes!, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 16),
            if (_unknownOutcomeMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_unknownOutcomeMessage!, style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                PdfButton(path: '/api/quotations/${q.id}/pdf', fileName: '${q.quotationNumber}.pdf'),
                WhatsappSendButton(messageType: 0, referenceType: 0, referenceId: q.id, defaultRecipientNumber: widget.customerPhone),
                if (canConvert)
                  FilledButton(
                    onPressed: _converting ? null : _convert,
                    child: _converting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_unknownOutcomeMessage != null ? 'Retry' : 'Convert to Invoice'),
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

Widget _quotationStatusPill(QuotationStatus status) => switch (status) {
      QuotationStatus.draft => StatusPill.draft('Draft'),
      QuotationStatus.issued => StatusPill.info('Issued'),
      QuotationStatus.converted => StatusPill.converted('Converted'),
      QuotationStatus.cancelled => StatusPill.cancelled('Cancelled'),
      QuotationStatus.expired => StatusPill.warning('Expired'),
    };

class _DraftLine {
  String? itemId;
  double quantity = 1;
  double rate = 0;
  double discount = 0;
  /// Optional manual serial pick for a serial-tracked item — empty means "let stock deduction
  /// auto-assign the oldest-received unit (FIFO) at conversion time", per business decision
  /// (2026-08-25): manual pick always wins over FIFO when supplied, but neither is required.
  List<String> serialNumbers = [];

  /// True for a typed-in Service line — no catalog Item at all (itemId stays null), the admin
  /// types the description/tax rate/SAC code directly instead of picking from the Items catalog.
  bool isService = false;
  String description = '';
  String? hsnCode;
  double taxRatePercent = 18;
}

class _CreateQuotationPage extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _CreateQuotationPage({required this.onDone});

  @override
  ConsumerState<_CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends ConsumerState<_CreateQuotationPage> {
  String? _customerId;
  final List<_DraftLine> _lines = [_DraftLine()];
  final _notes = TextEditingController();
  final _placeOfSupply = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _placeOfSupply.dispose();
    super.dispose();
  }

  /// Picking an item that's already on another line merges into that line's quantity instead of
  /// leaving a duplicate row — as long as the item isn't serial-tracked, where each unit needs its
  /// own distinct entry rather than being lumped into a shared quantity.
  void _onItemPicked(_DraftLine line, String? itemId, List<Item> items) {
    if (itemId == null) return;
    final item = items.firstWhere((it) => it.id == itemId);

    setState(() {
      final dupIndex = _lines.indexWhere((l) => l != line && l.itemId == itemId);
      if (dupIndex != -1 && !item.isSerialTracked) {
        // Merge into the existing line instead of leaving a duplicate row - but reset this row to
        // blank rather than removing it, so a trailing empty line is never lost from under the user.
        _lines[dupIndex].quantity += line.quantity > 0 ? line.quantity : 1;
        line.itemId = null;
        line.quantity = 1;
        line.rate = 0;
        line.discount = 0;
        line.serialNumbers = [];
        return;
      }

      line.itemId = itemId;
      line.rate = item.sellingPrice;
      // Picking an item on the last (empty) row means the user is about to keep adding lines —
      // save them the extra "Add line" click.
      if (_lines.last == line) _lines.add(_DraftLine());
    });
  }

  Future<void> _createCustomer() async {
    final newCustomerId = await showDialog<String>(context: context, builder: (_) => const CreateCustomerDialog());
    if (newCustomerId != null) setState(() => _customerId = newCustomerId);
  }

  Future<void> _save({required bool issue}) async {
    // A line with no item picked (and not a filled-in Service line) is just an unused blank row
    // (usually the trailing "add more" placeholder) - it should never block saving or need to be
    // filled in, only real lines count.
    final realLines = _lines.where((l) => l.itemId != null || (l.isService && l.description.trim().isNotEmpty)).toList();
    if (_customerId == null || realLines.isEmpty) {
      setState(() => _error = 'Select a customer and at least one item.');
      return;
    }
    if (realLines.any((l) => l.rate <= 0)) {
      setState(() => _error = 'Enter a price greater than 0 for every item/service line.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/quotations',
      (json) => json as Map<String, dynamic>,
      body: {
        'customerId': _customerId,
        'lines': realLines
            .map((l) => {
                  'itemId': l.itemId,
                  'description': l.isService ? l.description.trim() : '',
                  'quantity': l.quantity,
                  'rate': l.rate,
                  'discount': l.discount,
                  'taxRatePercent': l.isService ? l.taxRatePercent : null,
                  'serialNumbers': l.serialNumbers.isEmpty ? null : l.serialNumbers,
                  'hsnCode': l.isService && l.hsnCode != null && l.hsnCode!.trim().isNotEmpty ? l.hsnCode!.trim() : null,
                })
            .toList(),
        'overallDiscountType': null,
        'overallDiscountValue': 0,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'placeOfSupply': _placeOfSupply.text.trim().isEmpty ? null : _placeOfSupply.text.trim(),
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess(data: final data):
        if (issue) {
          final issueResult = await api.post<void>('/api/quotations/${data['id']}/issue', (_) {});
          if (!mounted) return;
          if (issueResult is ApiFailure || issueResult is ApiNetworkError) {
            // The quotation itself was created successfully - only the "mark as issued" step failed,
            // so don't discard the save; just surface it and leave the quotation as Draft.
            AppToast.error('Saved as Draft — could not mark as Issued.');
          }
        }
        ref.invalidate(quotationsProvider);
        widget.onDone();
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

    double subtotal = 0;
    for (final l in _lines) {
      final isRealLine = l.itemId != null || (l.isService && l.description.trim().isNotEmpty);
      if (!isRealLine) continue;
      subtotal += l.quantity * l.rate;
    }

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('New Quotation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('Quotation number is assigned automatically on save.', style: TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: widget.onDone),
                      ],
                    ),
                    const SizedBox(height: 20),
                    customersAsync.when(
                      data: (customers) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SearchableDropdown<String>(
                              label: 'Customer *',
                              value: _customerId,
                              items: customers.map((c) => c.id).toList(),
                              itemLabel: (id) => customers.firstWhere((c) => c.id == id).name,
                              onChanged: (v) => setState(() => _customerId = v),
                              validator: (v) => v == null ? 'Select a customer' : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            tooltip: 'New Customer',
                            onPressed: _createCustomer,
                          ),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Could not load customers.'),
                    ),
                    const SizedBox(height: 20),
                    Text('Line Items *', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppPalette.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                      child: const Row(
                        children: [
                          SizedBox(width: 50, child: Text('#')),
                          Expanded(flex: 4, child: Text('ITEM / SERVICE')),
                          Expanded(flex: 3, child: Text('SERIAL NO. / SAC')),
                          Expanded(flex: 2, child: Text('QTY')),
                          Expanded(flex: 2, child: Text('RATE')),
                          Expanded(flex: 2, child: Text('TAX %')),
                          Expanded(flex: 2, child: Text('AMOUNT')),
                          SizedBox(width: 32),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    itemsAsync.when(
                      data: (items) => Column(
                        children: [
                          ..._lines.asMap().entries.map((entry) => _LineRow(
                                key: ObjectKey(entry.value),
                                index: entry.key + 1,
                                items: items,
                                line: entry.value,
                                onChanged: () => setState(() {}),
                                onItemPicked: (itemId) => _onItemPicked(entry.value, itemId, items),
                                onRemove: _lines.length > 1 ? () => setState(() => _lines.removeAt(entry.key)) : null,
                              )),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() => _lines.add(_DraftLine())),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Line Item'),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Could not load items.'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _placeOfSupply,
                      decoration: const InputDecoration(
                        labelText: 'Place of Supply (optional)',
                        hintText: 'e.g. 29-Karnataka — where this order ships to, not the customer\'s address',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes / Terms (optional)', alignLabelWithHint: true),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: widget.onDone, child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _saving ? null : () => _save(issue: false),
                          child: _saving
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save as Draft'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saving ? null : () => _save(issue: true),
                          child: const Text('Issue Quotation'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineRow extends ConsumerStatefulWidget {
  final int index;
  final List<Item> items;
  final _DraftLine line;
  final VoidCallback onChanged;
  final ValueChanged<String?> onItemPicked;
  final VoidCallback? onRemove;

  const _LineRow({
    super.key,
    required this.index,
    required this.items,
    required this.line,
    required this.onChanged,
    required this.onItemPicked,
    this.onRemove,
  });

  @override
  ConsumerState<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends ConsumerState<_LineRow> {
  late final _qtyController = TextEditingController(text: formatQuantity(widget.line.quantity));
  late final _rateController = TextEditingController(text: widget.line.rate.toString());
  late final _serialController = TextEditingController(text: widget.line.serialNumbers.join(', '));
  late final _descriptionController = TextEditingController(text: widget.line.description);
  late final _hsnController = TextEditingController(text: widget.line.hsnCode ?? '');
  late final _taxRateController = TextEditingController(text: widget.line.taxRatePercent.toStringAsFixed(0));

  @override
  void didUpdateWidget(covariant _LineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent (e.g. merging a duplicate item into this line) can mutate widget.line's fields
    // directly without going through this row's own text fields — keep the display in sync.
    final qtyStr = formatQuantity(widget.line.quantity);
    if (_qtyController.text != qtyStr) _qtyController.text = qtyStr;
    final rateStr = widget.line.rate.toString();
    if (_rateController.text != rateStr) _rateController.text = rateStr;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rateController.dispose();
    _serialController.dispose();
    _descriptionController.dispose();
    _hsnController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  /// Switching a line between "pick from catalog" and "type it in" clears whichever fields only
  /// make sense in the other mode, so a leftover picked item or typed description never silently
  /// survives a mode switch and gets saved by mistake.
  void _toggleMode() {
    widget.line.isService = !widget.line.isService;
    if (widget.line.isService) {
      widget.line.itemId = null;
      widget.line.serialNumbers = [];
      _serialController.clear();
    } else {
      widget.line.description = '';
      widget.line.hsnCode = null;
      _descriptionController.clear();
      _hsnController.clear();
    }
    widget.onChanged();
  }

  /// Clears a "0" placeholder value the moment the field is tapped, so the user can just start
  /// typing the real quantity/rate instead of first selecting/deleting the 0 themselves.
  void _clearZeroOnTap(TextEditingController controller) {
    if (controller.text == '0') controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.line.itemId == null ? null : widget.items.firstWhere((it) => it.id == widget.line.itemId);
    final amount = widget.line.quantity * widget.line.rate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 20, child: Text('${widget.index}', style: TextStyle(color: AppPalette.textMuted))),
          Tooltip(
            message: widget.line.isService ? 'Typed Service — tap to switch to a catalog Item' : 'Catalog Item — tap to switch to a typed Service',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _toggleMode,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  widget.line.isService ? Icons.design_services_outlined : Icons.inventory_2_outlined,
                  size: 18,
                  color: widget.line.isService ? AppPalette.primary : AppPalette.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 4,
            child: widget.line.isService
                ? TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(hintText: 'Service description', isDense: true),
                    onChanged: (v) {
                      widget.line.description = v;
                      widget.onChanged();
                    },
                  )
                : SearchableDropdown<String>(
                    label: 'Item',
                    value: widget.line.itemId,
                    items: widget.items.map((it) => it.id).toList(),
                    itemLabel: (id) => widget.items.firstWhere((it) => it.id == id).name,
                    itemSecondaryLabel: (id) => widget.items.firstWhere((it) => it.id == id).sku,
                    onChanged: widget.onItemPicked,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: widget.line.isService
                ? TextFormField(
                    controller: _hsnController,
                    decoration: const InputDecoration(hintText: 'SAC Code (optional)', isDense: true),
                    onChanged: (v) => widget.line.hsnCode = v,
                  )
                // Optional even for a serial-tracked item — left blank, stock deduction auto-assigns
                // the oldest-received unit (FIFO) at conversion time instead.
                : TextFormField(
                    controller: _serialController,
                    enabled: selectedItem?.isSerialTracked ?? false,
                    decoration: const InputDecoration(hintText: 'e.g. SN-00123', isDense: true),
                    onChanged: (v) => widget.line.serialNumbers = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _qtyController,
              decoration: const InputDecoration(isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onTap: () => _clearZeroOnTap(_qtyController),
              onChanged: (v) {
                widget.line.quantity = double.tryParse(v) ?? 1;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _rateController,
              decoration: const InputDecoration(isDense: true),
              keyboardType: TextInputType.number,
              onTap: () => _clearZeroOnTap(_rateController),
              onChanged: (v) {
                widget.line.rate = double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: widget.line.isService
                ? TextFormField(
                    controller: _taxRateController,
                    decoration: const InputDecoration(isDense: true, suffixText: '%'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: (v) {
                      widget.line.taxRatePercent = double.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                  )
                : Text(selectedItem == null ? '-' : '${selectedItem.taxRatePercent.toStringAsFixed(0)}%', style: TextStyle(color: AppPalette.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(
            width: 32,
            child: widget.onRemove != null
                ? IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: widget.onRemove)
                : null,
          ),
        ],
      ),
    );
  }
}
