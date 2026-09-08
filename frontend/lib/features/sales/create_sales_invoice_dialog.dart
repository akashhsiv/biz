import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../customers/customers_provider.dart';
import '../items/item_model.dart';
import '../items/items_provider.dart';
import '../reports/document_payment_status.dart';
import 'sales_invoices_provider.dart';

class _SiDraftLine {
  String? itemId;
  String description = '';
  double quantity = 1;
  double rate = 0;
  double discount = 0;
  double taxRatePercent = 0;
}

/// Direct Sales Invoice creation — the product no longer routes sales through a
/// quotation/proforma pipeline (see SalesInvoicesController.Create), so this dialog builds the
/// invoice request in one step: customer, lines restricted to the current category's items (or a
/// manually typed service line), overall discount, due date, notes, and a Paid Amount that drives
/// the resulting Paid/Partial/Credit/Overdue status shown live as a preview.
class CreateSalesInvoiceDialog extends ConsumerStatefulWidget {
  final String categoryId;
  const CreateSalesInvoiceDialog({super.key, required this.categoryId});

  @override
  ConsumerState<CreateSalesInvoiceDialog> createState() => _CreateSalesInvoiceDialogState();
}

class _CreateSalesInvoiceDialogState extends ConsumerState<CreateSalesInvoiceDialog> {
  String? _customerId;
  final List<_SiDraftLine> _lines = [_SiDraftLine()];
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;
  String? _error;
  final String _idempotencyKey = DateTime.now().microsecondsSinceEpoch.toString();

  double get _subtotal => _lines.fold(0, (sum, l) => sum + (l.quantity * l.rate - l.discount));
  double get _taxTotal => _lines.fold(0, (sum, l) => sum + (l.quantity * l.rate - l.discount) * (l.taxRatePercent / 100));
  double get _overallDiscount => double.tryParse(_discountController.text) ?? 0;
  double get _grandTotal => (_subtotal + _taxTotal - _overallDiscount).clamp(0, double.infinity);
  double get _paidAmount => double.tryParse(_paidController.text) ?? 0;
  double get _outstanding => (_grandTotal - _paidAmount).clamp(0, double.infinity);

  DocumentPaymentStatus get _previewStatus {
    if (_outstanding <= 0.009) return DocumentPaymentStatus.paid;
    if (_paidAmount > 0) return DocumentPaymentStatus.partiallyPaid;
    if (_dueDate != null && _dueDate!.isBefore(DateTime.now())) return DocumentPaymentStatus.overdue;
    return DocumentPaymentStatus.credit;
  }

  Future<void> _save() async {
    final realLines = _lines.where((l) => l.itemId != null || l.description.trim().isNotEmpty).toList();
    if (_customerId == null || realLines.isEmpty) {
      setState(() => _error = 'Select a customer and at least one line item.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/sales-invoices',
      (json) => json as Map<String, dynamic>,
      idempotencyKey: _idempotencyKey,
      body: {
        'customerId': _customerId,
        'categoryId': widget.categoryId,
        'lines': realLines
            .map((l) => {
                  'itemId': l.itemId,
                  'description': l.description,
                  'quantity': l.quantity,
                  'rate': l.rate,
                  'discount': l.discount,
                  'taxRatePercent': l.itemId == null ? l.taxRatePercent : null,
                })
            .toList(),
        'overallDiscountType': _overallDiscount > 0 ? 1 : null,
        'overallDiscountValue': _overallDiscount,
        'dueDate': _dueDate?.toIso8601String(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'paidAmount': _paidAmount,
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(salesInvoicesProvider);
        ref.invalidate(salesInvoicesFilteredProvider);
        AppToast.success('Sales invoice created.');
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _dueDate ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: DateTime(now.year + 3));
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final itemsAsync = ref.watch(itemsFilteredProvider(ItemsFilter(categoryId: widget.categoryId)));

    return AlertDialog(
      title: const Text('New Sales Invoice'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 12),
              itemsAsync.when(
                data: (items) => Column(
                  children: [
                    ..._lines.asMap().entries.map((entry) => _SiLineRow(
                          items: items,
                          line: entry.value,
                          onChanged: () => setState(() {}),
                          onRemove: _lines.length > 1 ? () => setState(() => _lines.removeAt(entry.key)) : null,
                        )),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _lines.add(_SiDraftLine())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add line (pick an item, or leave blank and type a service)'),
                      ),
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load items for this category.'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discountController,
                      decoration: const InputDecoration(labelText: 'Overall Discount (₹)', isDense: true),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(_dueDate == null ? 'Due Date' : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes', isDense: true)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    _totalRow('Subtotal', _subtotal),
                    _totalRow('Tax', _taxTotal),
                    if (_overallDiscount > 0) _totalRow('Discount', -_overallDiscount),
                    const Divider(height: 16),
                    _totalRow('Grand Total', _grandTotal, bold: true),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _paidController,
                      decoration: const InputDecoration(labelText: 'Paid Amount (₹)', isDense: true),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding: ₹${_outstanding.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppPalette.textSecondary)),
                        _statusPill(_previewStatus),
                      ],
                    ),
                  ],
                ),
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

  Widget _statusPill(DocumentPaymentStatus status) {
    final color = switch (status) {
      DocumentPaymentStatus.paid => Colors.green,
      DocumentPaymentStatus.partiallyPaid => Colors.orange,
      DocumentPaymentStatus.credit => Colors.blue,
      DocumentPaymentStatus.overdue => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _SiLineRow extends StatelessWidget {
  final List<Item> items;
  final _SiDraftLine line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _SiLineRow({required this.items, required this.line, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SearchableDropdown<String>(
              label: 'Item (optional)',
              value: line.itemId,
              items: items.map((it) => it.id).toList(),
              itemLabel: (id) => items.firstWhere((it) => it.id == id).name,
              itemSecondaryLabel: (id) => items.firstWhere((it) => it.id == id).sku,
              onChanged: (v) {
                line.itemId = v;
                if (v != null) {
                  final item = items.firstWhere((it) => it.id == v);
                  line.rate = item.sellingPrice;
                  line.description = item.name;
                  line.taxRatePercent = item.taxRatePercent;
                }
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          if (line.itemId == null)
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: line.description,
                decoration: const InputDecoration(labelText: 'Service description', isDense: true),
                onChanged: (v) => line.description = v,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: line.quantity.toString(),
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: (v) {
                line.quantity = double.tryParse(v) ?? 1;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: ValueKey(line.rate),
              initialValue: line.rate.toString(),
              decoration: const InputDecoration(labelText: 'Rate', isDense: true),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                line.rate = double.tryParse(v) ?? 0;
                onChanged();
              },
            ),
          ),
          if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: onRemove),
        ],
      ),
    );
  }
}
