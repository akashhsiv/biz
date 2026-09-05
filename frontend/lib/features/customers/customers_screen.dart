import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'customer_model.dart';
import 'customers_provider.dart';

const _pageSize = 20;

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    showDialog(context: context, builder: (_) => const CreateCustomerDialog());
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.has(Permissions.customersManage);
    void refresh() => ref.invalidate(customersProvider);

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: canManage ? _showCreateDialog : null,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        floatingActionButton: canManage
            ? AppFab(onPressed: _showCreateDialog, tooltip: 'New Customer (Ctrl+N)', label: 'New Customer')
            : null,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Customers',
                subtitle: 'Manage your customer accounts and information',
                actions: [
                  SizedBox(
                    width: 240,
                    height: 40,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search customers...'),
                    ),
                  ),
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: customersAsync.when(
                  data: (customers) {
                    final query = _search.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? customers
                        : customers.where((c) => c.name.toLowerCase().contains(query) || c.customerCode.toLowerCase().contains(query)).toList();

                    return AppListCard(
                      emptyMessage: query.isEmpty ? 'No customers yet. Add your first customer to start creating invoices.' : 'No customers match "$query".',
                      emptyIcon: Icons.people_outline,
                      columns: const [
                        AppListColumn('Code', flex: 2),
                        AppListColumn('Name', flex: 3),
                        AppListColumn('Type', flex: 2),
                        AppListColumn('GST Number', flex: 2),
                        AppListColumn('Contact', flex: 2),
                      ],
                      itemCount: filtered.length,
                      itemsPerPage: _pageSize,
                      currentPage: _page,
                      onPageChange: (p) => setState(() => _page = p),
                      cellsBuilder: (context, i) {
                        final c = filtered[i];
                        return [
                          Text(c.customerCode, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(c.customerType == CustomerType.registered ? 'GST Registered' : 'Unregistered', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          Text(c.customerType == CustomerType.registered ? (c.gstNumber ?? '-') : '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          Text(c.contactNumber ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                        ];
                      },
                    );
                  },
                  loading: () => Card(child: SkeletonTableRows(columns: 5)),
                  error: (e, _) => Center(child: Text('Failed to load customers: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Public so it can be reused from other screens (e.g. Quotations) that need a quick "this
/// customer doesn't exist yet" escape hatch without leaving the document they're creating — pops
/// with the new customer's id so the caller can auto-select it.
class CreateCustomerDialog extends ConsumerStatefulWidget {
  const CreateCustomerDialog({super.key});

  @override
  ConsumerState<CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends ConsumerState<CreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gstNumber = TextEditingController();
  final _gstState = TextEditingController();
  final _contact = TextEditingController();
  CustomerType _type = CustomerType.unregistered;
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
      '/api/customers',
      (json) => json as Map<String, dynamic>,
      body: {
        'name': _name.text.trim(),
        'customerType': _type.index,
        'gstNumber': _type == CustomerType.registered ? _gstNumber.text.trim() : null,
        'gstState': _type == CustomerType.registered ? _gstState.text.trim() : null,
        'contactNumber': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        'email': null,
        'billingAddress': null,
        'shippingAddress': null,
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess(data: final data):
        ref.invalidate(customersProvider);
        Navigator.of(context).pop(data['id'] as String);
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
      title: const Text('New Customer'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppPalette.textSecondary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CustomerType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: CustomerType.unregistered, child: Text('Unregistered')),
                  DropdownMenuItem(value: CustomerType.registered, child: Text('GST Registered')),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              if (_type == CustomerType.registered) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstNumber,
                  decoration: const InputDecoration(labelText: 'GST Number *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'GST Number is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstState,
                  decoration: const InputDecoration(labelText: 'GST State *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'GST State is required' : null,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _contact,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
