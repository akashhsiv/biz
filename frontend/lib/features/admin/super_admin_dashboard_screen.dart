import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_result.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'admin_provider.dart';
import 'shop_model.dart';

/// Landing screen for a super admin (`AuthState.isSuperAdmin`) — provisioning-only, deliberately
/// simple v1: list shops, create a shop, create a shop's first admin. A super admin has no
/// UserShopRole for any shop, so this replaces ShopGate/AppShell entirely rather than sitting
/// inside them.
class SuperAdminDashboardScreen extends ConsumerStatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  ConsumerState<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends ConsumerState<SuperAdminDashboardScreen> {
  bool _activeOnly = false;

  void _showCreateShopDialog() {
    showDialog(context: context, builder: (_) => const _CreateShopDialog());
  }

  void _showCreateAdminDialog(Shop shop) {
    showDialog(context: context, builder: (_) => _CreateShopAdminDialog(shop: shop));
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(adminShopsProvider);
    void refresh() => ref.invalidate(adminShopsProvider);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      floatingActionButton: AppFab(onPressed: _showCreateShopDialog, tooltip: 'New Shop', label: 'New Shop'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: PageHeader(title: 'Super Admin', subtitle: 'Provision shops and their first admin users'),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: shopsAsync.when(
                  data: (shops) {
                    final filtered = _activeOnly ? shops.where((s) => s.isActive).toList() : shops;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${shops.length} shop${shops.length == 1 ? '' : 's'}',
                                style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 16),
                            FilterChip(
                              label: const Text('Active only'),
                              selected: _activeOnly,
                              onSelected: (v) => setState(() => _activeOnly = v),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: AppListCard(
                            emptyMessage: 'No shops yet. Create the first one.',
                            emptyIcon: Icons.storefront_outlined,
                            columns: const [
                              AppListColumn('Name', flex: 3),
                              AppListColumn('GSTIN', flex: 2),
                              AppListColumn('Status', flex: 1),
                              AppListColumn('Actions', flex: 2),
                            ],
                            itemCount: filtered.length,
                            cellsBuilder: (context, i) {
                              final shop = filtered[i];
                              return [
                                Text(shop.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(shop.gstin.isEmpty ? '-' : shop.gstin, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                                _StatusBadge(isActive: shop.isActive),
                                OutlinedButton.icon(
                                  onPressed: () => _showCreateAdminDialog(shop),
                                  icon: const Icon(Icons.person_add_alt_outlined, size: 16),
                                  label: const Text('Create Shop Admin'),
                                ),
                              ];
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Card(child: SkeletonTableRows(columns: 4)),
                  error: (e, _) => Center(child: Text('Failed to load shops: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

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

class _CreateShopDialog extends ConsumerStatefulWidget {
  const _CreateShopDialog();

  @override
  ConsumerState<_CreateShopDialog> createState() => _CreateShopDialogState();
}

class _CreateShopDialogState extends ConsumerState<_CreateShopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _contactNumber = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    _address.dispose();
    _contactNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref.read(adminActionsProvider).createShop(
          name: _name.text.trim(),
          gstin: _gstin.text.trim().isEmpty ? null : _gstin.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          contactNumber: _contactNumber.text.trim().isEmpty ? null : _contactNumber.text.trim(),
        );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(adminShopsProvider);
        Navigator.of(context).pop();
        AppToast.success('Shop created.');
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
      title: const Text('New Shop'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Shop Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Shop name is required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(controller: _gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextField(
                controller: _contactNumber,
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
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Create')),
      ],
    );
  }
}

class _CreateShopAdminDialog extends ConsumerStatefulWidget {
  final Shop shop;
  const _CreateShopAdminDialog({required this.shop});

  @override
  ConsumerState<_CreateShopAdminDialog> createState() => _CreateShopAdminDialogState();
}

class _CreateShopAdminDialogState extends ConsumerState<_CreateShopAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref.read(adminActionsProvider).createShopAdmin(
          shopId: widget.shop.id,
          username: _username.text.trim(),
          fullName: _fullName.text.trim(),
          password: _password.text.trim().isEmpty ? null : _password.text.trim(),
        );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess(data: final data):
        Navigator.of(context).pop();
        showDialog(context: context, builder: (_) => _AdminCreatedDialog(result: data));
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
      title: Text('Create Shop Admin — ${widget.shop.name}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'Leave blank to auto-generate a secure password',
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
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Create')),
      ],
    );
  }
}

/// Shown exactly once, right after `CreateShopAdmin` succeeds — the backend never returns this
/// plaintext password again, so the dialog leads with an unmissable warning and a one-tap copy.
class _AdminCreatedDialog extends StatelessWidget {
  final ShopAdminCreationResult result;
  const _AdminCreatedDialog({required this.result});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.password));
    AppToast.success('Password copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Shop Admin Created'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.errorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.errorText.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppPalette.errorText, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save this password now — it will not be shown again.',
                      style: TextStyle(color: AppPalette.errorText, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ReadOnlyRow(label: 'Username', value: result.username),
            const SizedBox(height: 8),
            _ReadOnlyRow(label: 'Full Name', value: result.fullName),
            const SizedBox(height: 8),
            _ReadOnlyRow(label: 'Password', value: result.password, monospace: true, onCopy: () => _copy(context)),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  final VoidCallback? onCopy;
  const _ReadOnlyRow({required this.label, required this.value, this.monospace = false, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13))),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: monospace ? 'monospace' : null),
          ),
        ),
        if (onCopy != null)
          IconButton(icon: const Icon(Icons.copy, size: 16), tooltip: 'Copy', onPressed: onCopy, visualDensity: VisualDensity.compact),
      ],
    );
  }
}
