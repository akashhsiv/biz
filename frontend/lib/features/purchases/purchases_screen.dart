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
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_button.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/pdf_button.dart';
import '../../shared/widgets/reason_dialog.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../items/brands_provider.dart';
import '../items/item_model.dart';
import '../items/items_provider.dart';
import '../reports/document_payment_status.dart';
import '../users/user_directory_provider.dart';
import 'purchase_order_model.dart';
import 'purchases_provider.dart';
import 'supplier_model.dart';

const _pageSize = 20;

Widget _poStatusPill(PurchaseOrderStatus status) => switch (status) {
      PurchaseOrderStatus.draft => StatusPill.draft('Draft'),
      PurchaseOrderStatus.submitted => StatusPill.info('Submitted'),
      PurchaseOrderStatus.processing => StatusPill.warning('Processing'),
      PurchaseOrderStatus.partiallyCompleted => StatusPill.warning('Partially Completed'),
      PurchaseOrderStatus.completed => StatusPill.link('Received'),
      PurchaseOrderStatus.cancelled => StatusPill.cancelled('Cancelled'),
    };

Widget _poPaymentStatusPill(PurchasePaymentStatus status) => switch (status) {
      PurchasePaymentStatus.processing => StatusPill.warning('Processing'),
      PurchasePaymentStatus.completed => StatusPill.success('Completed'),
      PurchasePaymentStatus.cancelled => StatusPill.cancelled('Cancelled'),
    };

Widget _balancePaymentStatusPill(DocumentPaymentStatus status) => switch (status) {
      DocumentPaymentStatus.paid => StatusPill.success(status.label),
      DocumentPaymentStatus.partiallyPaid => StatusPill.warning(status.label),
      DocumentPaymentStatus.credit => StatusPill.info(status.label),
      DocumentPaymentStatus.overdue => StatusPill.error(status.label),
    };

/// Vendor management — reachable as its own top-level nav entry now that Purchase Orders live
/// under each Category's workspace (see CategoryWorkspaceScreen) instead of a flat "Purchases"
/// screen. Vendor-Brand linking (needed for the Purchase create flow's Vendor -> Brand cascade)
/// happens from a supplier's row action here.
class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: AppPalette.surface, body: _SuppliersTab());
  }
}

// ---------- Suppliers ----------

class _SuppliersTab extends ConsumerStatefulWidget {
  const _SuppliersTab();

  @override
  ConsumerState<_SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends ConsumerState<_SuppliersTab> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    void openCreate() => showDialog(context: context, builder: (_) => const _CreateSupplierDialog());

    return ListScreenShortcuts(
      tabIndex: 1,
      onRefresh: () => ref.invalidate(suppliersProvider),
      onNew: openCreate,
      child: Scaffold(
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'New Supplier (Ctrl+N)', label: 'New Supplier'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Suppliers',
                subtitle: 'Vendors you place purchase orders with',
                actions: [
                  OutlinedButton.icon(onPressed: () => ref.invalidate(suppliersProvider), icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: suppliersAsync.when(
                  data: (suppliers) => AppListCard(
                    emptyMessage: 'No suppliers yet.',
                    emptyIcon: Icons.local_shipping_outlined,
                    columns: const [
                      AppListColumn('Name', flex: 3),
                      AppListColumn('State', flex: 2),
                      AppListColumn('GST Number', flex: 2),
                      AppListColumn('Contact', flex: 2),
                      AppListColumn('Brands', flex: 2),
                    ],
                    itemCount: suppliers.length,
                    itemsPerPage: _pageSize,
                    currentPage: _page,
                    onPageChange: (p) => setState(() => _page = p),
                    cellsBuilder: (context, i) {
                      final s = suppliers[i];
                      return [
                        Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(s.state ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        Text(s.gstNumber ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        Text(s.contactNumber ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        TextButton(
                          onPressed: () => showDialog(context: context, builder: (_) => ManageVendorBrandsDialog(supplier: s)),
                          child: const Text('Manage'),
                        ),
                      ];
                    },
                  ),
                  loading: () => Card(child: SkeletonTableRows(columns: 4)),
                  error: (e, _) => Center(child: Text('Failed to load suppliers: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateSupplierDialog extends ConsumerStatefulWidget {
  const _CreateSupplierDialog();

  @override
  ConsumerState<_CreateSupplierDialog> createState() => _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends ConsumerState<_CreateSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gstNumber = TextEditingController();
  final _state = TextEditingController();
  final _contact = TextEditingController();
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
      '/api/suppliers',
      (json) => json as Map<String, dynamic>,
      body: {
        'name': _name.text.trim(),
        'gstNumber': _gstNumber.text.trim().isEmpty ? null : _gstNumber.text.trim(),
        'state': _state.text.trim().isEmpty ? null : _state.text.trim(),
        'contactNumber': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        'address': null,
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(suppliersProvider);
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
      title: const Text('New Supplier'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 8),
            TextField(controller: _gstNumber, decoration: const InputDecoration(labelText: 'GST Number')),
            const SizedBox(height: 8),
            TextField(controller: _state, decoration: const InputDecoration(labelText: 'State')),
            const SizedBox(height: 8),
            TextField(
              controller: _contact,
              decoration: const InputDecoration(labelText: 'Contact Number'),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

// ---------- Purchase Orders ----------

String _formatPoDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// The Purchase List tab of a Category's workspace (see CategoryWorkspaceScreen) — every purchase
/// order shown here belongs to [categoryId], with the full filter set the backend supports
/// (supplier, brand, status, balance payment status, date range, search, overdue-only).
class CategoryPurchaseOrdersTab extends ConsumerStatefulWidget {
  final String categoryId;
  const CategoryPurchaseOrdersTab({super.key, required this.categoryId});

  @override
  ConsumerState<CategoryPurchaseOrdersTab> createState() => _CategoryPurchaseOrdersTabState();
}

class _CategoryPurchaseOrdersTabState extends ConsumerState<CategoryPurchaseOrdersTab> {
  String? _selectedId;
  final _search = TextEditingController();
  PurchaseOrderStatus? _statusFilter;
  DocumentPaymentStatus? _balanceFilter;
  String? _supplierFilter;
  String? _brandFilter;
  DateTime? _from;
  DateTime? _to;
  bool _overdueOnly = false;

  PurchaseListFilter get _filter => PurchaseListFilter(
        categoryId: widget.categoryId,
        supplierId: _supplierFilter,
        brandId: _brandFilter,
        status: _statusFilter,
        balancePaymentStatus: _balanceFilter,
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
    final ordersAsync = ref.watch(purchaseOrdersFilteredProvider(filter));
    final suppliersAsync = ref.watch(suppliersProvider);
    final brandsAsync = ref.watch(brandsProvider(widget.categoryId));
    final usersAsync = ref.watch(userDirectoryProvider);
    void openCreate() => showDialog(context: context, builder: (_) => _CreatePurchaseOrderDialog(categoryId: widget.categoryId));
    void refresh() => ref.invalidate(purchaseOrdersFilteredProvider(filter));

    return ListScreenShortcuts(
      tabIndex: 0,
      onRefresh: refresh,
      onNew: openCreate,
      child: Scaffold(
        floatingActionButton: AppFab(onPressed: openCreate, tooltip: 'New Purchase Order (Ctrl+N)', label: 'New Purchase Order'),
        body: ordersAsync.when(
          data: (orders) {
            final suppliers = suppliersAsync.valueOrNull ?? [];
            final brands = brandsAsync.valueOrNull ?? [];
            final nameOf = {for (final s in suppliers) s.id: s.name};
            final userNameOf = <String, String>{for (final u in usersAsync.valueOrNull ?? const []) u.id: u.fullName};

            final selected = orders.where((o) => o.id == _selectedId).firstOrNull;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Purchase List',
                    subtitle: 'Orders placed with suppliers and their receiving/payment status',
                    actions: [
                      SizedBox(
                        width: 220,
                        height: 40,
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search PO #...'),
                        ),
                      ),
                      FilterButton<String>(
                        value: _supplierFilter,
                        allLabel: 'All Suppliers',
                        options: suppliers.map((s) => s.id).toList(),
                        labelOf: (id) => nameOf[id] ?? id,
                        onChanged: (v) => setState(() => _supplierFilter = v),
                      ),
                      FilterButton<String>(
                        value: _brandFilter,
                        allLabel: 'All Brands',
                        options: brands.map((b) => b.id).toList(),
                        labelOf: (id) => brands.where((b) => b.id == id).firstOrNull?.name ?? id,
                        onChanged: (v) => setState(() => _brandFilter = v),
                      ),
                      FilterButton<PurchaseOrderStatus>(
                        value: _statusFilter,
                        allLabel: 'All Statuses',
                        options: PurchaseOrderStatus.values,
                        labelOf: (s) => s.name,
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      FilterButton<DocumentPaymentStatus>(
                        value: _balanceFilter,
                        allLabel: 'All Balances',
                        options: DocumentPaymentStatus.values,
                        labelOf: (s) => s.label,
                        onChanged: (v) => setState(() => _balanceFilter = v),
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
                    child: orders.isEmpty
                        ? const Center(child: Text('No purchase orders found.'))
                        : selected == null
                            ? _PurchaseOrderListCard(
                                orders: orders,
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
                                    child: _PurchaseOrderListCard(
                                      orders: orders,
                                      nameOf: nameOf,
                                      userNameOf: userNameOf,
                                      selectedId: selected.id,
                                      onSelect: (id) => setState(() => _selectedId = id),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _PurchaseOrderDetailPanel(order: selected, supplierName: nameOf[selected.supplierId] ?? '-'),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            );
          },
          loading: () => Padding(padding: const EdgeInsets.all(24), child: Card(child: SkeletonTableRows(columns: 8))),
          error: (e, _) => Center(child: Text('Failed to load purchase orders: $e')),
        ),
      ),
    );
  }
}

class _PurchaseOrderListCard extends StatelessWidget {
  final List<PurchaseOrder> orders;
  final Map<String, String> nameOf;
  final Map<String, String> userNameOf;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _PurchaseOrderListCard({required this.orders, required this.nameOf, required this.userNameOf, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return AppListCard(
      emptyMessage: 'No purchase orders found.',
      emptyIcon: Icons.local_shipping_outlined,
      columns: const [
        AppListColumn('PO #', flex: 3),
        AppListColumn('Supplier', flex: 4),
        AppListColumn('Date', flex: 3),
        AppListColumn('Total', flex: 2),
        AppListColumn('Status', flex: 3),
        AppListColumn('Payment', flex: 3),
        AppListColumn('Balance', flex: 3),
        AppListColumn('Created By', flex: 3),
      ],
      itemCount: orders.length,
      isSelected: (i) => orders[i].id == selectedId,
      onRowTap: (i) => onSelect(orders[i].id),
      cellsBuilder: (context, i) {
        final o = orders[i];
        return [
          Text(o.poNumber, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(nameOf[o.supplierId] ?? '-', style: const TextStyle(fontSize: 13)),
          Text(_formatPoDate(o.createdAt), style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
          Text('₹${o.grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          _poStatusPill(o.status),
          _poPaymentStatusPill(o.paymentStatus),
          _balancePaymentStatusPill(o.balancePaymentStatus),
          Text(userNameOf[o.createdBy] ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
        ];
      },
    );
  }
}

class _PurchaseOrderDetailPanel extends ConsumerStatefulWidget {
  final PurchaseOrder order;
  final String supplierName;
  const _PurchaseOrderDetailPanel({required this.order, required this.supplierName});

  @override
  ConsumerState<_PurchaseOrderDetailPanel> createState() => _PurchaseOrderDetailPanelState();
}

class _PurchaseOrderDetailPanelState extends ConsumerState<_PurchaseOrderDetailPanel> {
  bool _busy = false;

  Future<void> _runSimple(Future<ApiResult<void>> Function() call, {void Function()? onSuccess}) async {
    setState(() => _busy = true);
    final result = await call();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(purchaseOrdersProvider);
        ref.invalidate(purchaseOrdersFilteredProvider);
        onSuccess?.call();
      case ApiFailure(message: final msg):
        AppToast.error(msg);
      case ApiNetworkError(message: final msg):
        AppToast.error('Could not reach the Host: $msg');
    }
  }

  Future<void> _submit() async {
    final api = ref.read(apiClientProvider);
    await _runSimple(() => api.post('/api/purchase-orders/${widget.order.id}/submit', (_) {}));
  }

  Future<void> _cancel() async {
    final reason = await showReasonDialog(context, title: 'Cancel Purchase Order');
    if (reason == null) return;
    final api = ref.read(apiClientProvider);
    await _runSimple(() => api.post('/api/purchase-orders/${widget.order.id}/cancel', (_) {}, body: {'reason': reason}));
  }

  Future<void> _receive() async {
    await showDialog(context: context, builder: (_) => _ReceiveDialog(order: widget.order));
    ref.invalidate(purchaseOrdersProvider);
  }

  Future<void> _addPayment() async {
    final amountController = TextEditingController(text: widget.order.grandTotal.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Payment'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(amountController.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount == null) return;

    final api = ref.read(apiClientProvider);
    await _runSimple(() => api.post(
          '/api/purchase-orders/${widget.order.id}/payments',
          (_) {},
          body: {'amount': amount, 'paymentMethod': 'bank_transfer'},
        ));
  }

  Future<void> _completePayment(String paymentId) async {
    final api = ref.read(apiClientProvider);
    await _runSimple(() => api.post('/api/purchase-orders/${widget.order.id}/payments/$paymentId/complete', (_) {}));
  }

  @override
  Widget build(BuildContext context) {
    // Watches the list so this panel reflects the current order right after any action here
    // invalidates it, instead of being frozen on the `widget.order` snapshot from when it opened.
    final ordersAsync = ref.watch(purchaseOrdersProvider);
    final o = ordersAsync.valueOrNull?.firstWhere((p) => p.id == widget.order.id, orElse: () => widget.order) ?? widget.order;

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
                      Text(o.poNumber, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
                      const SizedBox(height: 2),
                      Text(widget.supplierName, style: TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _poStatusPill(o.status),
                  const SizedBox(height: 4),
                  _poPaymentStatusPill(o.paymentStatus),
                  const SizedBox(height: 4),
                  _balancePaymentStatusPill(o.balancePaymentStatus),
                  if (o.outstandingTotal > 0) ...[
                    const SizedBox(height: 4),
                    Text('Outstanding: ₹${o.outstandingTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppPalette.textSecondary)),
                  ],
                ]),
              ],
            ),
            const SizedBox(height: 16),
            Text('Lines', style: Theme.of(context).textTheme.titleSmall),
            const Divider(height: 16),
            ...o.lines.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Qty ${l.quantityOrdered} received ${l.quantityReceived} @ ₹${l.rate}', style: const TextStyle(fontSize: 13)),
                )),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${o.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (o.payments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Payments', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...o.payments.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(p.paymentMethod ?? '-', style: TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (p.status == PurchasePaymentStatus.processing)
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), minimumSize: const Size(0, 32)),
                            onPressed: () => _completePayment(p.id),
                            child: const Text('Complete'),
                          )
                        else
                          _poPaymentStatusPill(p.status),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  PdfButton(path: '/api/purchase-orders/${o.id}/pdf', fileName: '${o.poNumber}.pdf'),
                  if (o.status == PurchaseOrderStatus.draft) FilledButton(onPressed: _submit, child: const Text('Submit')),
                  if (o.status == PurchaseOrderStatus.submitted || o.status == PurchaseOrderStatus.processing)
                    FilledButton(onPressed: _receive, child: const Text('Receive Goods')),
                  if (o.status != PurchaseOrderStatus.completed &&
                      o.status != PurchaseOrderStatus.cancelled &&
                      ref.watch(authControllerProvider).has(Permissions.purchaseOrdersCancel))
                    OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(foregroundColor: AppPalette.error, side: const BorderSide(color: AppPalette.error)),
                      child: const Text('Cancel PO'),
                    ),
                  if (o.paymentStatus != PurchasePaymentStatus.completed)
                    OutlinedButton(onPressed: _addPayment, child: const Text('Add Payment')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveDialog extends ConsumerStatefulWidget {
  final PurchaseOrder order;
  const _ReceiveDialog({required this.order});

  @override
  ConsumerState<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends ConsumerState<_ReceiveDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, TextEditingController> _serialControllers;
  late final Map<String, TextEditingController> _batchNumberControllers;
  final Map<String, DateTime?> _expiryDates = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final l in widget.order.lines)
        l.id: TextEditingController(text: (l.quantityOrdered - l.quantityReceived).toString()),
    };
    _serialControllers = {for (final l in widget.order.lines) l.id: TextEditingController()};
    _batchNumberControllers = {for (final l in widget.order.lines) l.id: TextEditingController()};
  }

  Future<void> _save() async {
    final items = ref.read(itemsProvider).valueOrNull ?? [];

    final lines = <Map<String, dynamic>>[];
    for (final l in widget.order.lines) {
      final quantity = double.tryParse(_controllers[l.id]!.text) ?? 0;
      if (quantity <= 0) continue;

      final item = items.where((i) => i.id == l.itemId).firstOrNull;
      List<String>? serialNumbers;
      String? batchNumber;
      if (item != null && item.isSerialTracked) {
        serialNumbers = _serialControllers[l.id]!.text.split(RegExp(r'[\n,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (serialNumbers.length != quantity.toInt()) {
          setState(() => _error = 'Enter exactly ${quantity.toInt()} serial number(s) for ${item.name}.');
          return;
        }
      } else if (item != null && item.isBatchTracked) {
        final entered = _batchNumberControllers[l.id]!.text.trim();
        if (entered.isEmpty) {
          setState(() => _error = 'Enter a batch number for ${item.name}.');
          return;
        }
        batchNumber = entered;
      }

      lines.add({
        'poLineId': l.id,
        'quantityReceived': quantity,
        'batchNumber': batchNumber,
        'expiryDate': _expiryDates[l.id]?.toIso8601String(),
        'serialNumbers': serialNumbers,
      });
    }

    if (lines.isEmpty) {
      setState(() => _error = 'Enter a quantity for at least one line.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/purchase-orders/${widget.order.id}/receipts',
      (json) => json as Map<String, dynamic>,
      body: {'lines': lines},
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
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
    final itemsAsync = ref.watch(itemsProvider);

    return AlertDialog(
      title: const Text('Receive Goods'),
      content: SizedBox(
        width: 360,
        child: itemsAsync.when(
          data: (items) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.order.lines.map((l) {
                final item = items.firstWhere((i) => i.id == l.itemId, orElse: () => Item(
                      id: l.itemId,
                      sku: '?',
                      name: '?',
                      unit: '',
                      itemKind: ItemKind.stock,
                      purchasePrice: 0,
                      sellingPrice: 0,
                      isBatchTracked: false,
                      isActive: true,
                      stockOnHand: 0,
                    ));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _controllers[l.id],
                        decoration: InputDecoration(labelText: '${item.name} (ordered ${l.quantityOrdered}, received ${l.quantityReceived})'),
                        keyboardType: TextInputType.number,
                      ),
                      if (item.isSerialTracked) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: _serialControllers[l.id],
                          decoration: const InputDecoration(labelText: 'Serial numbers (one per line, or comma-separated)', isDense: true),
                          maxLines: 2,
                        ),
                      ],
                      if (item.isBatchTracked) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _batchNumberControllers[l.id],
                                decoration: const InputDecoration(labelText: 'Batch number', isDense: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _expiryDates[l.id] ?? DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                                  );
                                  if (picked != null) setState(() => _expiryDates[l.id] = picked);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Expiry (optional)', isDense: true),
                                  child: Text(
                                    _expiryDates[l.id] == null
                                        ? '-'
                                        : '${_expiryDates[l.id]!.year}-${_expiryDates[l.id]!.month.toString().padLeft(2, '0')}-${_expiryDates[l.id]!.day.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load items.'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

class _CreatePurchaseOrderDialog extends ConsumerStatefulWidget {
  final String categoryId;
  const _CreatePurchaseOrderDialog({required this.categoryId});

  @override
  ConsumerState<_CreatePurchaseOrderDialog> createState() => _CreatePurchaseOrderDialogState();
}

class _PoDraftLine {
  String? itemId;
  double quantity = 1;
  double rate = 0;
}

class _CreatePurchaseOrderDialogState extends ConsumerState<_CreatePurchaseOrderDialog> {
  String? _supplierId;
  String? _brandId;
  final List<_PoDraftLine> _lines = [_PoDraftLine()];
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    // A line with no item picked is just an unused blank row - it should never block saving or
    // need to be filled in, only real lines count.
    final realLines = _lines.where((l) => l.itemId != null).toList();
    if (_supplierId == null || _brandId == null || realLines.isEmpty) {
      setState(() => _error = 'Select a vendor, a brand, and at least one item.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/purchase-orders',
      (json) => json as Map<String, dynamic>,
      body: {
        'supplierId': _supplierId,
        'categoryId': widget.categoryId,
        'lines': realLines.map((l) => {'itemId': l.itemId, 'quantityOrdered': l.quantity, 'rate': l.rate}).toList(),
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(purchaseOrdersProvider);
        ref.invalidate(purchaseOrdersFilteredProvider);
        AppToast.success('Purchase order created.');
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
    final suppliersAsync = ref.watch(suppliersProvider);
    final vendorBrandsAsync = _supplierId == null ? null : ref.watch(vendorBrandsProvider(_supplierId));
    final itemsAsync = _brandId == null
        ? null
        : ref.watch(itemsFilteredProvider(ItemsFilter(categoryId: widget.categoryId, brandId: _brandId)));

    return AlertDialog(
      title: const Text('New Purchase Order'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              suppliersAsync.when(
                data: (suppliers) => SearchableDropdown<String>(
                  label: 'Vendor',
                  value: _supplierId,
                  items: suppliers.map((s) => s.id).toList(),
                  itemLabel: (id) => suppliers.firstWhere((s) => s.id == id).name,
                  onChanged: (v) => setState(() {
                    _supplierId = v;
                    _brandId = null;
                  }),
                  validator: (v) => v == null ? 'Select a vendor' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load vendors.'),
              ),
              const SizedBox(height: 12),
              if (_supplierId == null)
                const Text('Select a vendor to see the brands they supply.', style: TextStyle(color: AppPalette.textMuted, fontSize: 12))
              else
                vendorBrandsAsync!.when(
                  data: (links) => links.isEmpty
                      ? const Text('This vendor has no brands linked yet — link one from Suppliers first.',
                          style: TextStyle(color: AppPalette.error, fontSize: 12))
                      : SearchableDropdown<String>(
                          label: 'Brand',
                          value: _brandId,
                          items: links.map((l) => l.brandId).toList(),
                          itemLabel: (id) => links.firstWhere((l) => l.brandId == id).brandName,
                          onChanged: (v) => setState(() => _brandId = v),
                          validator: (v) => v == null ? 'Select a brand' : null,
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Could not load this vendor\'s brands.'),
                ),
              const SizedBox(height: 12),
              if (_brandId == null)
                const Text('Select a brand to add line items.', style: TextStyle(color: AppPalette.textMuted, fontSize: 12))
              else
                itemsAsync!.when(
                  data: (items) => Column(
                    children: [
                      ..._lines.asMap().entries.map((entry) => _PoLineRow(
                            items: items,
                            line: entry.value,
                            onChanged: () => setState(() {}),
                            onRemove: _lines.length > 1 ? () => setState(() => _lines.removeAt(entry.key)) : null,
                          )),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _lines.add(_PoDraftLine())),
                          icon: const Icon(Icons.add),
                          label: const Text('Add line'),
                        ),
                      ),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Could not load items.'),
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

class _PoLineRow extends StatelessWidget {
  final List<Item> items;
  final _PoDraftLine line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _PoLineRow({required this.items, required this.line, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SearchableDropdown<String>(
              label: 'Item',
              value: line.itemId,
              items: items.map((it) => it.id).toList(),
              itemLabel: (id) => items.firstWhere((it) => it.id == id).name,
              itemSecondaryLabel: (id) => items.firstWhere((it) => it.id == id).sku,
              onChanged: (v) {
                line.itemId = v;
                final item = items.firstWhere((it) => it.id == v);
                line.rate = item.purchasePrice;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: formatQuantity(line.quantity),
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: (v) => line.quantity = double.tryParse(v) ?? 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: ValueKey(line.rate),
              initialValue: line.rate.toString(),
              decoration: const InputDecoration(labelText: 'Rate', isDense: true),
              keyboardType: TextInputType.number,
              onChanged: (v) => line.rate = double.tryParse(v) ?? 0,
            ),
          ),
          if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: onRemove),
        ],
      ),
    );
  }
}

/// Lets a Shop Admin link/unlink the Brands a Vendor is set up to supply — this is the set a
/// Purchase Order line's Item.Brand must belong to when ordering from that vendor (backend-
/// enforced in PurchaseOrdersController.Create).
class ManageVendorBrandsDialog extends ConsumerStatefulWidget {
  final Supplier supplier;
  const ManageVendorBrandsDialog({super.key, required this.supplier});

  @override
  ConsumerState<ManageVendorBrandsDialog> createState() => _ManageVendorBrandsDialogState();
}

class _ManageVendorBrandsDialogState extends ConsumerState<ManageVendorBrandsDialog> {
  String? _addBrandId;
  bool _busy = false;

  Future<void> _link(String brandId) async {
    setState(() => _busy = true);
    final error = await linkVendorBrand(ref, widget.supplier.id, brandId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _addBrandId = null;
    });
    if (error != null) {
      AppToast.error(error);
    } else {
      ref.invalidate(vendorBrandsProvider(widget.supplier.id));
    }
  }

  Future<void> _unlink(String brandId) async {
    setState(() => _busy = true);
    final error = await unlinkVendorBrand(ref, widget.supplier.id, brandId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      AppToast.error(error);
    } else {
      ref.invalidate(vendorBrandsProvider(widget.supplier.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedAsync = ref.watch(vendorBrandsProvider(widget.supplier.id));
    final allBrandsAsync = ref.watch(brandsProvider(null));

    return AlertDialog(
      title: Text('${widget.supplier.name} — Brands'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              linkedAsync.when(
                data: (links) => links.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No brands linked yet.'))
                    : Column(
                        children: links
                            .map((l) => ListTile(
                                  dense: true,
                                  title: Text(l.brandName),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: _busy ? null : () => _unlink(l.brandId),
                                  ),
                                ))
                            .toList(),
                      ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load: $e'),
              ),
              const Divider(),
              allBrandsAsync.when(
                data: (allBrands) {
                  final linkedIds = linkedAsync.valueOrNull?.map((l) => l.brandId).toSet() ?? {};
                  final available = allBrands.where((b) => !linkedIds.contains(b.id)).toList();
                  if (available.isEmpty) return const Text('Every active brand is already linked.');
                  return Row(
                    children: [
                      Expanded(
                        child: SearchableDropdown<String>(
                          label: 'Link a brand',
                          value: _addBrandId,
                          items: available.map((b) => b.id).toList(),
                          itemLabel: (id) => available.firstWhere((b) => b.id == id).name,
                          onChanged: (v) => setState(() => _addBrandId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy || _addBrandId == null ? null : () => _link(_addBrandId!),
                        child: const Text('Link'),
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load brands: $e'),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
