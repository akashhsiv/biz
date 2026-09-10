import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'tax_groups_provider.dart';

/// Minimal Shop-Admin screen for Tax Groups (Name + Rate %) — list plus an inline create form, same
/// simplicity as [ManageCategoriesDialog] since the backend exposes only GET/POST (no deactivate).
/// Reached from its own top-level nav entry (see app.dart), gated by items.manage — the permission
/// the backend's LookupsController actually requires for tax-group writes.
class TaxGroupsScreen extends ConsumerStatefulWidget {
  const TaxGroupsScreen({super.key});

  @override
  ConsumerState<TaxGroupsScreen> createState() => _TaxGroupsScreenState();
}

class _TaxGroupsScreenState extends ConsumerState<TaxGroupsScreen> {
  final _nameController = TextEditingController();
  final _rateController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final rate = double.tryParse(_rateController.text.trim());
    if (name.isEmpty || rate == null) {
      AppToast.error('Enter a name and a valid rate.');
      return;
    }

    setState(() => _saving = true);
    final error = await createTaxGroup(ref, name, rate);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      AppToast.error(error);
    } else {
      _nameController.clear();
      _rateController.clear();
      ref.invalidate(taxGroupsProvider);
      AppToast.success('Tax group created.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxGroupsAsync = ref.watch(taxGroupsProvider);
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.has(Permissions.itemsManage);
    void refresh() => ref.invalidate(taxGroupsProvider);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Tax Groups',
              subtitle: 'Tax rates available when creating Items',
              actions: [
                OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
              ],
            ),
            const SizedBox(height: 16),
            if (canManage)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'New tax group name', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _rateController,
                          decoration: const InputDecoration(labelText: 'Rate %', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(onPressed: _saving ? null : _create, child: const Text('Add')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: taxGroupsAsync.when(
                data: (taxGroups) => AppListCard(
                  emptyMessage: 'No tax groups yet. Add your first one above.',
                  emptyIcon: Icons.percent_outlined,
                  columns: const [
                    AppListColumn('Name', flex: 3),
                    AppListColumn('Rate %', flex: 2, numeric: true),
                  ],
                  itemCount: taxGroups.length,
                  cellsBuilder: (context, i) {
                    final t = taxGroups[i];
                    return [
                      Text(t.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(t.ratePercent.toStringAsFixed(2), style: const TextStyle(fontSize: 13)),
                    ];
                  },
                ),
                loading: () => const Card(child: SkeletonTableRows(columns: 2)),
                error: (e, _) => Center(child: Text('Failed to load tax groups: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
