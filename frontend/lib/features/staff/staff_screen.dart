import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'salary_screen.dart';
import 'staff_model.dart';
import 'staff_provider.dart';

const _pageSize = 20;

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final _search = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    showDialog(context: context, builder: (_) => const StaffFormDialog());
  }

  void _showEditDialog(Staff staff) {
    showDialog(context: context, builder: (_) => StaffFormDialog(staff: staff));
  }

  Future<void> _deactivate(Staff staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Staff'),
        content: Text('Deactivate ${staff.name}? They will no longer appear as active staff.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/staff/${staff.id}/deactivate', (_) {});
    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(staffListProvider);
      case ApiFailure(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      case ApiNetworkError(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reach the Host: $msg')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.has(Permissions.staffManage);
    final canViewSalary = auth.has(Permissions.staffSalaryView);
    void refresh() => ref.invalidate(staffListProvider);

    return ListScreenShortcuts(
      onRefresh: refresh,
      onNew: canManage ? _showCreateDialog : null,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        floatingActionButton: canManage
            ? AppFab(onPressed: _showCreateDialog, tooltip: 'New Staff (Ctrl+N)', label: 'New Staff')
            : null,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Staff',
                subtitle: 'Manage staff records and salary rates',
                actions: [
                  SizedBox(
                    width: 240,
                    height: 40,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search staff...'),
                    ),
                  ),
                  OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: staffAsync.when(
                  data: (staff) {
                    final query = _search.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? staff
                        : staff
                            .where((s) =>
                                s.name.toLowerCase().contains(query) ||
                                s.employeeCode.toLowerCase().contains(query) ||
                                (s.mobile ?? '').toLowerCase().contains(query))
                            .toList();

                    return AppListCard(
                      emptyMessage: query.isEmpty ? 'No staff yet. Add your first staff member.' : 'No staff match "$query".',
                      emptyIcon: Icons.badge_outlined,
                      columns: const [
                        AppListColumn('Code', flex: 2),
                        AppListColumn('Name', flex: 3),
                        AppListColumn('Designation', flex: 2),
                        AppListColumn('Status', flex: 2),
                        AppListColumn('Net Salary', flex: 2, numeric: true),
                        AppListColumn('Actions', flex: 3),
                      ],
                      itemCount: filtered.length,
                      itemsPerPage: _pageSize,
                      currentPage: _page,
                      onPageChange: (p) => setState(() => _page = p),
                      onRowTap: canViewSalary
                          ? (i) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalaryScreen(staff: filtered[i])))
                          : null,
                      cellsBuilder: (context, i) {
                        final s = filtered[i];
                        return [
                          Text(s.employeeCode, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(s.designation ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                          _StatusBadge(status: s.employmentStatus, isActive: s.isActive),
                          Text(s.netSalary.toStringAsFixed(2), style: const TextStyle(fontSize: 13)),
                          Row(
                            children: [
                              if (canManage) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit',
                                  onPressed: () => _showEditDialog(s),
                                ),
                                if (s.isActive)
                                  IconButton(
                                    icon: const Icon(Icons.block, size: 18),
                                    tooltip: 'Deactivate',
                                    onPressed: () => _deactivate(s),
                                  ),
                              ],
                              if (canViewSalary)
                                IconButton(
                                  icon: const Icon(Icons.payments_outlined, size: 18),
                                  tooltip: 'Salary',
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalaryScreen(staff: s))),
                                ),
                            ],
                          ),
                        ];
                      },
                    );
                  },
                  loading: () => Card(child: SkeletonTableRows(columns: 6)),
                  error: (e, _) => Center(child: Text('Failed to load staff: $e')),
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
  final StaffEmploymentStatus status;
  final bool isActive;
  const _StatusBadge({required this.status, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = !isActive || status == StaffEmploymentStatus.terminated
        ? Colors.red
        : status == StaffEmploymentStatus.inactive
            ? Colors.orange
            : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(staffEmploymentStatusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class StaffFormDialog extends ConsumerStatefulWidget {
  final Staff? staff;
  const StaffFormDialog({super.key, this.staff});

  @override
  ConsumerState<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.staff?.name ?? '');
  late final _employeeCode = TextEditingController(text: widget.staff?.employeeCode ?? '');
  late final _mobile = TextEditingController(text: widget.staff?.mobile ?? '');
  late final _address = TextEditingController(text: widget.staff?.address ?? '');
  late final _designation = TextEditingController(text: widget.staff?.designation ?? '');
  late final _basicSalary = TextEditingController(text: widget.staff?.basicSalary.toStringAsFixed(2) ?? '0');
  late final _allowances = TextEditingController(text: widget.staff?.allowances.toStringAsFixed(2) ?? '0');
  late final _deductions = TextEditingController(text: widget.staff?.deductions.toStringAsFixed(2) ?? '0');
  late final _notes = TextEditingController(text: widget.staff?.notes ?? '');
  late DateTime _joiningDate = widget.staff?.joiningDate ?? DateTime.now();
  late StaffEmploymentStatus _employmentStatus = widget.staff?.employmentStatus ?? StaffEmploymentStatus.active;
  late StaffSalaryType _salaryType = widget.staff?.salaryType ?? StaffSalaryType.monthly;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.staff != null;

  @override
  void dispose() {
    _name.dispose();
    _employeeCode.dispose();
    _mobile.dispose();
    _address.dispose();
    _designation.dispose();
    _basicSalary.dispose();
    _allowances.dispose();
    _deductions.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final body = {
      'name': _name.text.trim(),
      'employeeCode': _employeeCode.text.trim(),
      'mobile': _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'joiningDate': _joiningDate.toIso8601String(),
      'designation': _designation.text.trim().isEmpty ? null : _designation.text.trim(),
      'categoryId': null,
      'employmentStatus': _employmentStatus.index,
      'salaryType': _salaryType.index,
      'basicSalary': double.tryParse(_basicSalary.text.trim()) ?? 0,
      'allowances': double.tryParse(_allowances.text.trim()) ?? 0,
      'deductions': double.tryParse(_deductions.text.trim()) ?? 0,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };

    final result = _isEdit
        ? await api.put<Map<String, dynamic>>('/api/staff/${widget.staff!.id}', (json) => json as Map<String, dynamic>, body: body)
        : await api.post<Map<String, dynamic>>('/api/staff', (json) => json as Map<String, dynamic>, body: body);

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(staffListProvider);
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
      title: Text(_isEdit ? 'Edit Staff' : 'New Staff'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _employeeCode,
                  decoration: const InputDecoration(labelText: 'Employee Code *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Employee code is required' : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mobile,
                  decoration: const InputDecoration(labelText: 'Mobile'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 12),
                TextField(controller: _designation, decoration: const InputDecoration(labelText: 'Designation')),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickJoiningDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Joining Date'),
                    child: Text('${_joiningDate.year}-${_joiningDate.month.toString().padLeft(2, '0')}-${_joiningDate.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<StaffEmploymentStatus>(
                        initialValue: _employmentStatus,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: StaffEmploymentStatus.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(staffEmploymentStatusLabel(s))))
                            .toList(),
                        onChanged: (v) => setState(() => _employmentStatus = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<StaffSalaryType>(
                        initialValue: _salaryType,
                        decoration: const InputDecoration(labelText: 'Salary Type'),
                        items: StaffSalaryType.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(staffSalaryTypeLabel(s))))
                            .toList(),
                        onChanged: (v) => setState(() => _salaryType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _basicSalary,
                        decoration: const InputDecoration(labelText: 'Basic Salary'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _allowances,
                        decoration: const InputDecoration(labelText: 'Allowances'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deductions,
                  decoration: const InputDecoration(labelText: 'Deductions'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
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
