import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'salary_model.dart';
import 'salary_provider.dart';
import 'staff_model.dart';

/// Per-staff salary history, reached by tapping a row (or the "Salary" action) on the Staff list.
/// The backend nests this route under api/staff/{staffId}/salary with no flat "all records" list
/// endpoint, so a per-staff drill-down screen is the natural fit rather than a top-level tab.
class SalaryScreen extends ConsumerStatefulWidget {
  final Staff staff;
  const SalaryScreen({super.key, required this.staff});

  @override
  ConsumerState<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends ConsumerState<SalaryScreen> {
  bool _generating = false;

  Future<void> _generateThisMonth() async {
    final now = DateTime.now();
    setState(() => _generating = true);

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/staff/${widget.staff.id}/salary',
      (json) => json as Map<String, dynamic>,
      body: {'staffId': widget.staff.id, 'periodMonth': now.month, 'periodYear': now.year},
    );

    if (!mounted) return;
    setState(() => _generating = false);

    switch (result) {
      case ApiSuccess():
        ref.invalidate(staffSalaryListProvider(widget.staff.id));
      case ApiFailure(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      case ApiNetworkError(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reach the Host: $msg')));
    }
  }

  void _recordPayment(SalaryPayment record) {
    showDialog(
      context: context,
      builder: (_) => RecordSalaryPaymentDialog(staffId: widget.staff.id, record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canPay = auth.has(Permissions.staffSalaryPay);
    final salaryAsync = ref.watch(staffSalaryListProvider(widget.staff.id));
    void refresh() => ref.invalidate(staffSalaryListProvider(widget.staff.id));

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        title: Text('${widget.staff.name} — Salary'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Salary History',
              subtitle: '${widget.staff.employeeCode} · ${staffSalaryTypeLabel(widget.staff.salaryType)} · Net ${widget.staff.netSalary.toStringAsFixed(2)}',
              actions: [
                OutlinedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                const SizedBox(width: 8),
                if (canPay)
                  FilledButton.icon(
                    onPressed: _generating ? null : _generateThisMonth,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Generate This Month'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: salaryAsync.when(
                data: (records) => AppListCard(
                  emptyMessage: 'No salary records yet for this staff member.',
                  emptyIcon: Icons.payments_outlined,
                  columns: const [
                    AppListColumn('Period', flex: 2),
                    AppListColumn('Net Salary', flex: 2, numeric: true),
                    AppListColumn('Paid', flex: 2, numeric: true),
                    AppListColumn('Pending', flex: 2, numeric: true),
                    AppListColumn('Status', flex: 2),
                    AppListColumn('Actions', flex: 2),
                  ],
                  itemCount: records.length,
                  cellsBuilder: (context, i) {
                    final r = records[i];
                    return [
                      Text('${monthNames[r.periodMonth - 1]} ${r.periodYear}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(r.netSalary.toStringAsFixed(2), style: const TextStyle(fontSize: 13)),
                      Text(r.paidAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary)),
                      Text(r.pendingAmount.toStringAsFixed(2), style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary)),
                      _SalaryStatusBadge(status: r.status),
                      canPay && r.status != SalaryPaymentStatus.paid
                          ? OutlinedButton(onPressed: () => _recordPayment(r), child: const Text('Record Payment'))
                          : const SizedBox.shrink(),
                    ];
                  },
                ),
                loading: () => Card(child: SkeletonTableRows(columns: 6)),
                error: (e, _) => Center(child: Text('Failed to load salary records: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalaryStatusBadge extends StatelessWidget {
  final SalaryPaymentStatus status;
  const _SalaryStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SalaryPaymentStatus.paid => Colors.green,
      SalaryPaymentStatus.partiallyPaid => Colors.orange,
      SalaryPaymentStatus.pending => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(salaryPaymentStatusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class RecordSalaryPaymentDialog extends ConsumerStatefulWidget {
  final String staffId;
  final SalaryPayment record;
  const RecordSalaryPaymentDialog({super.key, required this.staffId, required this.record});

  @override
  ConsumerState<RecordSalaryPaymentDialog> createState() => _RecordSalaryPaymentDialogState();
}

class _RecordSalaryPaymentDialogState extends ConsumerState<RecordSalaryPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.record.pendingAmount.toStringAsFixed(2));
  final _paymentMethod = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _paymentMethod.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.record.pendingAmount) {
      setState(() => _error = 'Amount must be between 0 and ${widget.record.pendingAmount.toStringAsFixed(2)}.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/api/staff/${widget.staffId}/salary/${widget.record.id}/payments',
      (json) => json as Map<String, dynamic>,
      body: {
        'amount': amount,
        'paymentMethod': _paymentMethod.text.trim().isEmpty ? null : _paymentMethod.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      },
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess():
        ref.invalidate(staffSalaryListProvider(widget.staffId));
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
      title: const Text('Record Salary Payment'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Net: ${widget.record.netSalary.toStringAsFixed(2)}  ·  Paid: ${widget.record.paidAmount.toStringAsFixed(2)}  ·  Pending: ${widget.record.pendingAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppPalette.textSecondary)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Amount is required' : null,
              ),
              const SizedBox(height: 12),
              TextField(controller: _paymentMethod, decoration: const InputDecoration(labelText: 'Payment Method')),
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
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
