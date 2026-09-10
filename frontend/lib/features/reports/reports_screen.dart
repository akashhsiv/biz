import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/report_pdf_export.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'customer_report_model.dart';
import 'document_payment_status.dart';
import 'reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final canViewCustomer = auth.has(Permissions.reportsCustomerView);

    void refresh() {
      ref.invalidate(salesReportProvider);
      ref.invalidate(purchaseReportProvider);
      ref.invalidate(lowStockReportProvider);
      ref.invalidate(financeReportProvider);
      ref.invalidate(outstandingReportProvider);
      ref.invalidate(auditReportProvider);
      if (canViewCustomer) ref.invalidate(customerReportProvider);
    }

    final tabs = [
      const Tab(text: 'Sales'),
      const Tab(text: 'Purchase'),
      const Tab(text: 'Low Stock'),
      const Tab(text: 'Finance'),
      if (canViewCustomer) const Tab(text: 'Customer'),
      const Tab(text: 'Audit'),
    ];
    final tabViews = [
      const _SalesReportTab(),
      const _PurchaseReportTab(),
      const _LowStockTab(),
      const _FinanceReportTab(),
      if (canViewCustomer) const _CustomerReportTab(),
      const _AuditReportTab(),
    ];

    return ListScreenShortcuts(
      onRefresh: refresh,
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          backgroundColor: AppPalette.surface,
          body: Column(
            children: [
              Container(
                color: AppPalette.card,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Reports', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppPalette.textPrimary)),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: refresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh (F5)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      // Explicit colors, not the app's default TabBarTheme - that theme is tuned for
                      // white-on-dark (the top AppBar), which would be invisible on this white card.
                      labelColor: AppPalette.primary,
                      unselectedLabelColor: AppPalette.textSecondary,
                      indicatorColor: AppPalette.primary,
                      tabs: tabs,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(children: tabViews),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width scaffolding shared by every report tab: a page title + Export PDF action, then
/// whatever content the tab supplies (stat tiles, charts, tables) laid out edge-to-edge instead of
/// the old narrow ListView that left most of a wide window empty.
class _ReportPage extends StatelessWidget {
  final String title;
  final VoidCallback? onExportPdf;
  final List<Widget> children;

  const _ReportPage({required this.title, required this.onExportPdf, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onExportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Responsive row of stat tiles, same sizing rule as the Dashboard's, so Reports reads as part of
/// the same visual system instead of a plain table screen.
class _StatRow extends StatelessWidget {
  final List<_Stat> stats;
  const _StatRow(this.stats);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth > 900 ? stats.length.clamp(1, 4) : constraints.maxWidth > 600 ? 2 : 1;
        final tileWidth = (constraints.maxWidth - (perRow - 1) * 16) / perRow;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final s in stats) SizedBox(width: tileWidth, child: s)],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.icon, required this.label, required this.value, this.color = AppPalette.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppPalette.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card wrapper used for every chart/table section so they all share the same framing.
/// Same title treatment as [_SectionCard] but without its own card chrome — for a section whose
/// child (an [AppListCard]) already draws its own Card, so this avoids nesting one Card inside another.
class _TitledSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _TitledSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Horizontal-bar ranking chart for "top N by value" breakdowns (by customer/item/supplier) —
/// reads better than a bare table for spotting who/what dominates at a glance.
class _RankingBarChart extends StatelessWidget {
  final List<(String label, double value)> entries;
  final Color color;

  const _RankingBarChart({required this.entries, this.color = AppPalette.primary});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No data.'));

    final top = entries.take(8).toList();
    final maxValue = top.map((e) => e.$2).fold<double>(0, (a, b) => a > b ? a : b);

    // +96 accounts for the rotated bottom-axis labels' reservedSize below - omitting it made the
    // outer box shorter than the chart actually needs, overflowing by exactly that much whenever
    // there were few enough bars for the bar area alone to undercut the label space.
    return SizedBox(
      height: 32.0 * top.length + 16 + 96,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue <= 0 ? 1 : maxValue * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem('₹${rod.toY.toStringAsFixed(2)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 96,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= top.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Transform.rotate(
                      angle: -0.4,
                      child: Text(
                        top[i].$1,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          barGroups: [
            for (var i = 0; i < top.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: top[i].$2, color: color, width: 18, borderRadius: BorderRadius.circular(4)),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Small donut for a handful of named amounts (Amount In / Out / Refunds) — good enough for a
/// three-to-four-slice breakdown without needing a legend-heavy full pie chart library setup.
class _BreakdownDonut extends StatelessWidget {
  final List<(String label, double value, Color color)> slices;
  const _BreakdownDonut(this.slices);

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, s) => a + s.$2.abs());
    if (total <= 0) return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No data.'));

    return Row(
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (final s in slices)
                  if (s.$2.abs() > 0)
                    PieChartSectionData(
                      value: s.$2.abs(),
                      color: s.$3,
                      title: '${(s.$2.abs() / total * 100).toStringAsFixed(0)}%',
                      radius: 40,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.$1)),
                      Text('₹${s.$2.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dropdown for filtering a report by [DocumentPaymentStatus], shared by the Sales and Purchase
/// report tabs.
Widget _paymentStatusFilterDropdown(DocumentPaymentStatus? value, ValueChanged<DocumentPaymentStatus?> onChanged) {
  return SizedBox(
    width: 200,
    child: DropdownButtonFormField<DocumentPaymentStatus?>(
      initialValue: value,
      decoration: const InputDecoration(isDense: true, labelText: 'Payment Status', border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<DocumentPaymentStatus?>(value: null, child: Text('All')),
        for (final s in DocumentPaymentStatus.values) DropdownMenuItem<DocumentPaymentStatus?>(value: s, child: Text(s.label)),
      ],
      onChanged: onChanged,
    ),
  );
}

class _SalesReportTab extends ConsumerStatefulWidget {
  const _SalesReportTab();

  @override
  ConsumerState<_SalesReportTab> createState() => _SalesReportTabState();
}

class _SalesReportTabState extends ConsumerState<_SalesReportTab> {
  DocumentPaymentStatus? _paymentStatus;

  @override
  Widget build(BuildContext context) {
    final filter = PaymentStatusReportFilter(paymentStatus: _paymentStatus);
    final reportAsync = ref.watch(salesReportProvider(filter));
    final filterBar = Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _paymentStatusFilterDropdown(_paymentStatus, (v) => setState(() => _paymentStatus = v)),
    );

    return reportAsync.when(
      data: (r) {
        if (r == null) return const Center(child: Text('Could not load report.'));
        final byCustomer = r['byCustomer'] as List;
        final byItem = r['byItem'] as List;

        final byCustomerRows = byCustomer.map((c) => [c['customerName'] as String, '₹${(c['grandTotal'] as num).toStringAsFixed(2)}', '${c['invoiceCount']}']).toList();
        final byItemRows = byItem.map((it) => [it['itemName'] as String, '₹${(it['lineTotal'] as num).toStringAsFixed(2)}']).toList();

        final byCustomerChart = byCustomer.map((c) => (c['customerName'] as String, (c['grandTotal'] as num).toDouble())).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
        final byItemChart = byItem.map((it) => (it['itemName'] as String, (it['lineTotal'] as num).toDouble())).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

        return _ReportPage(
          title: 'Sales Report',
          onExportPdf: () => exportReportPdf(
            title: 'Sales Report',
            stats: [
              ('Total Sales', '₹${(r['totalSales'] as num).toStringAsFixed(2)}'),
              ('Invoices', '${r['invoiceCount']}'),
            ],
            sections: [
              ReportPdfSection(title: 'By Customer', columns: const ['Customer', 'Total', 'Invoices'], rows: byCustomerRows),
              ReportPdfSection(title: 'By Item', columns: const ['Item', 'Total'], rows: byItemRows),
            ],
          ),
          children: [
            filterBar,
            _StatRow([
              _Stat(icon: Icons.point_of_sale_outlined, label: 'Total Sales', value: '₹${(r['totalSales'] as num).toStringAsFixed(2)}', color: AppPalette.success),
              _Stat(icon: Icons.receipt_long_outlined, label: 'Invoices', value: '${r['invoiceCount']}'),
            ]),
            const SizedBox(height: 20),
            _SectionCard(title: 'Top Customers', child: _RankingBarChart(entries: byCustomerChart, color: AppPalette.primary)),
            const SizedBox(height: 20),
            _SectionCard(title: 'Top Items', child: _RankingBarChart(entries: byItemChart, color: AppPalette.success)),
            const SizedBox(height: 20),
            _TitledSection(title: 'By Customer', child: _breakdownTable(context, const ['Customer', 'Total', 'Invoices'], byCustomerRows)),
            const SizedBox(height: 20),
            _TitledSection(title: 'By Item', child: _breakdownTable(context, const ['Item', 'Total'], byItemRows)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
    );
  }
}

/// Small ranking table shared by the report tabs' breakdown sections (By Customer, By Item,
/// By Supplier, Customer Outstanding) — same shape everywhere, so build it once.
Widget _breakdownTable(BuildContext context, List<String> columns, Iterable<List<String>> rows, {String emptyMessage = 'No data.'}) {
  final rowsList = rows.toList();
  return AppListCard(
    shrinkWrap: true,
    emptyMessage: emptyMessage,
    columns: columns.map((c) => AppListColumn(c)).toList(),
    itemCount: rowsList.length,
    cellsBuilder: (context, i) => rowsList[i].map((v) => Text(v, style: const TextStyle(fontSize: 13))).toList(),
  );
}

class _PurchaseReportTab extends ConsumerStatefulWidget {
  const _PurchaseReportTab();

  @override
  ConsumerState<_PurchaseReportTab> createState() => _PurchaseReportTabState();
}

class _PurchaseReportTabState extends ConsumerState<_PurchaseReportTab> {
  DocumentPaymentStatus? _paymentStatus;

  @override
  Widget build(BuildContext context) {
    final filter = PaymentStatusReportFilter(paymentStatus: _paymentStatus);
    final reportAsync = ref.watch(purchaseReportProvider(filter));
    final filterBar = Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _paymentStatusFilterDropdown(_paymentStatus, (v) => setState(() => _paymentStatus = v)),
    );

    return reportAsync.when(
      data: (r) {
        if (r == null) return const Center(child: Text('Could not load report.'));
        final bySupplier = r['bySupplier'] as List;
        final bySupplierRows = bySupplier.map((s) => [s['supplierName'] as String, '₹${(s['grandTotal'] as num).toStringAsFixed(2)}', '${s['orderCount']}']).toList();
        final bySupplierChart = bySupplier.map((s) => (s['supplierName'] as String, (s['grandTotal'] as num).toDouble())).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

        return _ReportPage(
          title: 'Purchase Report',
          onExportPdf: () => exportReportPdf(
            title: 'Purchase Report',
            stats: [
              ('Total Purchases', '₹${(r['totalPurchases'] as num).toStringAsFixed(2)}'),
              ('Orders', '${r['orderCount']}'),
            ],
            sections: [
              ReportPdfSection(title: 'By Supplier', columns: const ['Supplier', 'Total', 'Orders'], rows: bySupplierRows),
            ],
          ),
          children: [
            filterBar,
            _StatRow([
              _Stat(icon: Icons.local_shipping_outlined, label: 'Total Purchases', value: '₹${(r['totalPurchases'] as num).toStringAsFixed(2)}', color: AppPalette.primary),
              _Stat(icon: Icons.assignment_outlined, label: 'Orders', value: '${r['orderCount']}'),
            ]),
            const SizedBox(height: 20),
            _SectionCard(title: 'Top Suppliers', child: _RankingBarChart(entries: bySupplierChart, color: AppPalette.primary)),
            const SizedBox(height: 20),
            _TitledSection(title: 'By Supplier', child: _breakdownTable(context, const ['Supplier', 'Total', 'Orders'], bySupplierRows)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
    );
  }
}

class _LowStockTab extends ConsumerWidget {
  const _LowStockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(lowStockReportProvider);

    return rowsAsync.when(
      data: (rows) {
        if (rows == null) return const Center(child: Text('Could not load report.'));

        final lowStockRows = rows.map((row) {
          final r = row as Map<String, dynamic>;
          return [r['sku'] as String, r['name'] as String, '${r['quantityOnHand']}'];
        }).toList();

        return _ReportPage(
          title: 'Low Stock Report',
          onExportPdf: () => exportReportPdf(
            title: 'Low Stock Report',
            stats: [('Items Below Threshold', '${rows.length}')],
            sections: [ReportPdfSection(title: 'Items', columns: const ['SKU', 'Name', 'Quantity On Hand'], rows: lowStockRows)],
          ),
          children: [
            _StatRow([
              _Stat(
                icon: Icons.warning_amber_rounded,
                label: 'Items Below Threshold',
                value: '${rows.length}',
                color: rows.isNotEmpty ? Colors.red : AppPalette.textMuted,
              ),
            ]),
            const SizedBox(height: 20),
            _TitledSection(
              title: 'Items',
              child: AppListCard(
                shrinkWrap: true,
                emptyMessage: 'No low-stock items.',
                emptyIcon: Icons.inventory_2_outlined,
                columns: const [
                  AppListColumn('SKU', flex: 2),
                  AppListColumn('Name', flex: 3),
                  AppListColumn('Quantity On Hand', flex: 2, numeric: true),
                ],
                itemCount: rows.length,
                cellsBuilder: (context, i) {
                  final r = rows[i] as Map<String, dynamic>;
                  return [
                    Text(r['sku'] as String, style: const TextStyle(fontSize: 13)),
                    Text(r['name'] as String, style: const TextStyle(fontSize: 13)),
                    Text('${r['quantityOnHand']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ];
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
    );
  }
}

class _FinanceReportTab extends ConsumerWidget {
  const _FinanceReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(financeReportProvider);
    final outstandingAsync = ref.watch(outstandingReportProvider);

    final report = reportAsync.valueOrNull;
    final outstandingRows = (outstandingAsync.valueOrNull ?? []).map((row) {
      final r = row as Map<String, dynamic>;
      return [r['customerName'] as String, '₹${(r['outstandingTotal'] as num).toStringAsFixed(2)}'];
    }).toList();

    return _ReportPage(
      title: 'Finance Report',
      onExportPdf: report == null
          ? null
          : () => exportReportPdf(
                title: 'Finance Report',
                stats: [
                  ('Amount In', '₹${(report['amountIn'] as num).toStringAsFixed(2)}'),
                  ('Amount Out', '₹${(report['amountOut'] as num).toStringAsFixed(2)}'),
                  ('Refunds', '₹${(report['refunds'] as num).toStringAsFixed(2)}'),
                  ('Ending Balance', '₹${(report['endingBalance'] as num).toStringAsFixed(2)}'),
                ],
                sections: [ReportPdfSection(title: 'Customer Outstanding', columns: const ['Customer', 'Outstanding'], rows: outstandingRows)],
              ),
      children: [
        reportAsync.when(
          data: (r) => r == null
              ? const Text('Could not load finance summary.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow([
                      _Stat(icon: Icons.arrow_downward, label: 'Amount In', value: '₹${(r['amountIn'] as num).toStringAsFixed(2)}', color: AppPalette.success),
                      _Stat(icon: Icons.arrow_upward, label: 'Amount Out', value: '₹${(r['amountOut'] as num).toStringAsFixed(2)}', color: AppPalette.error),
                      _Stat(icon: Icons.undo, label: 'Refunds', value: '₹${(r['refunds'] as num).toStringAsFixed(2)}', color: Colors.orange),
                      _Stat(icon: Icons.account_balance_wallet_outlined, label: 'Ending Balance', value: '₹${(r['endingBalance'] as num).toStringAsFixed(2)}'),
                    ]),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Breakdown',
                      child: _BreakdownDonut([
                        ('Amount In', (r['amountIn'] as num).toDouble(), AppPalette.success),
                        ('Amount Out', (r['amountOut'] as num).toDouble(), AppPalette.error),
                        ('Refunds', (r['refunds'] as num).toDouble(), Colors.orange),
                      ]),
                    ),
                  ],
                ),
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: LinearProgressIndicator()),
          error: (e, _) => Text('Failed: $e'),
        ),
        const SizedBox(height: 20),
        outstandingAsync.when(
          data: (rows) => _TitledSection(
            title: 'Customer Outstanding',
            child: _breakdownTable(context, const ['Customer', 'Outstanding'], outstandingRows, emptyMessage: 'No outstanding balances.')
          ),
          loading: () => Card(child: SkeletonTableRows(columns: 2, rowCount: 4)),
          error: (e, _) => Text('Failed: $e'),
        ),
      ],
    );
  }
}

class _CustomerReportTab extends ConsumerStatefulWidget {
  const _CustomerReportTab();

  @override
  ConsumerState<_CustomerReportTab> createState() => _CustomerReportTabState();
}

class _CustomerReportTabState extends ConsumerState<_CustomerReportTab> {
  DateTime? _from;
  DateTime? _to;
  final _customerIdController = TextEditingController();
  String? _appliedCustomerId;

  @override
  void dispose() {
    _customerIdController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = CustomerReportFilter(from: _from, to: _to, customerId: _appliedCustomerId);
    final rowsAsync = ref.watch(customerReportProvider(filter));

    Widget dateChip(String label, DateTime? value, VoidCallback onTap) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_today_outlined, size: 14),
        label: Text(value == null ? label : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'),
      );
    }

    final filterBar = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        dateChip('From', _from, () => _pickDate(isFrom: true)),
        dateChip('To', _to, () => _pickDate(isFrom: false)),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _customerIdController,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Customer ID (optional)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => setState(() => _appliedCustomerId = v.trim().isEmpty ? null : v.trim()),
          ),
        ),
        OutlinedButton(
          onPressed: () => setState(() => _appliedCustomerId = _customerIdController.text.trim().isEmpty ? null : _customerIdController.text.trim()),
          child: const Text('Apply'),
        ),
        if (_from != null || _to != null || _appliedCustomerId != null)
          TextButton(
            onPressed: () => setState(() {
              _from = null;
              _to = null;
              _appliedCustomerId = null;
              _customerIdController.clear();
            }),
            child: const Text('Clear'),
          ),
      ],
    );

    return rowsAsync.when(
      data: (rows) {
        if (rows == null) return const Center(child: Text('Could not load report.'));

        final totalSales = rows.fold<double>(0, (a, r) => a + r.totalSales);
        final totalOutstanding = rows.fold<double>(0, (a, r) => a + r.totalOutstanding);
        final totalPayments = rows.fold<double>(0, (a, r) => a + r.totalPayments);
        final totalInvoices = rows.fold<int>(0, (a, r) => a + r.invoiceCount);

        final summaryRows = rows
            .map((r) => [
                  r.customerName,
                  '₹${r.totalSales.toStringAsFixed(2)}',
                  '₹${r.totalOutstanding.toStringAsFixed(2)}',
                  '₹${r.totalPayments.toStringAsFixed(2)}',
                  '${r.invoiceCount}',
                ])
            .toList();

        return _ReportPage(
          title: 'Customer Report',
          onExportPdf: () => exportReportPdf(
            title: 'Customer Report',
            stats: [
              ('Total Sales', '₹${totalSales.toStringAsFixed(2)}'),
              ('Total Outstanding', '₹${totalOutstanding.toStringAsFixed(2)}'),
              ('Total Payments', '₹${totalPayments.toStringAsFixed(2)}'),
              ('Invoices', '$totalInvoices'),
            ],
            sections: [
              ReportPdfSection(
                title: 'By Customer',
                columns: const ['Customer', 'Sales', 'Outstanding', 'Payments', 'Invoices'],
                rows: summaryRows,
              ),
            ],
          ),
          children: [
            filterBar,
            const SizedBox(height: 20),
            _StatRow([
              _Stat(icon: Icons.point_of_sale_outlined, label: 'Total Sales', value: '₹${totalSales.toStringAsFixed(2)}', color: AppPalette.success),
              _Stat(icon: Icons.account_balance_wallet_outlined, label: 'Total Outstanding', value: '₹${totalOutstanding.toStringAsFixed(2)}', color: AppPalette.error),
              _Stat(icon: Icons.payments_outlined, label: 'Total Payments', value: '₹${totalPayments.toStringAsFixed(2)}'),
              _Stat(icon: Icons.receipt_long_outlined, label: 'Invoices', value: '$totalInvoices'),
            ]),
            const SizedBox(height: 20),
            _TitledSection(
              title: 'By Customer',
              child: rows.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No data.'))
                  : Column(children: [for (final r in rows) _CustomerReportExpansionRow(row: r)]),
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(24), child: filterBar),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (e, _) => Center(child: Text('Failed: $e')),
    );
  }
}

/// One customer's summary row, expandable to reveal the Products breakdown and the
/// date-wise activity timeline the backend returns alongside it.
class _CustomerReportExpansionRow extends StatelessWidget {
  final CustomerReportRow row;
  const _CustomerReportExpansionRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(row.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${row.invoiceCount} invoice(s)'),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${row.totalSales.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Outstanding ₹${row.totalOutstanding.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppPalette.textMuted)),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _StatRow([
              _Stat(icon: Icons.point_of_sale_outlined, label: 'Sales', value: '₹${row.totalSales.toStringAsFixed(2)}', color: AppPalette.success),
              _Stat(icon: Icons.account_balance_wallet_outlined, label: 'Outstanding', value: '₹${row.totalOutstanding.toStringAsFixed(2)}', color: AppPalette.error),
              _Stat(icon: Icons.payments_outlined, label: 'Payments', value: '₹${row.totalPayments.toStringAsFixed(2)}'),
            ]),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Products', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            _breakdownTable(
              context,
              const ['Item', 'Quantity', 'Amount'],
              row.products.map((p) => [p.itemName, p.quantity.toStringAsFixed(2), '₹${p.amount.toStringAsFixed(2)}']),
              emptyMessage: 'No products in this period.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Date-wise Activity', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            _breakdownTable(
              context,
              const ['Date', 'Amount', 'Invoices'],
              row.dateWiseActivity.map((a) => [
                    '${a.date.year}-${a.date.month.toString().padLeft(2, '0')}-${a.date.day.toString().padLeft(2, '0')}',
                    '₹${a.amount.toStringAsFixed(2)}',
                    '${a.invoiceCount}',
                  ]),
              emptyMessage: 'No activity in this period.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditReportTab extends ConsumerWidget {
  const _AuditReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(auditReportProvider);

    return rowsAsync.when(
      data: (rows) {
        if (rows == null) return const Center(child: Text('Could not load report.'));

        final auditRows = rows.map((row) {
          final r = row as Map<String, dynamic>;
          return [r['action'] as String, '${r['count']}'];
        }).toList();
        final auditChart = rows.map((row) {
          final r = row as Map<String, dynamic>;
          return (r['action'] as String, (r['count'] as num).toDouble());
        }).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

        return _ReportPage(
          title: 'Audit Report',
          onExportPdf: () => exportReportPdf(
            title: 'Audit Report',
            stats: const [],
            sections: [ReportPdfSection(title: 'Actions', columns: const ['Action', 'Count'], rows: auditRows)],
          ),
          children: [
            _SectionCard(title: 'Actions by Frequency', child: _RankingBarChart(entries: auditChart, color: AppPalette.primaryDark)),
            const SizedBox(height: 20),
            _TitledSection(
              title: 'Actions',
              child: _breakdownTable(context, const ['Action', 'Count'], auditRows),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
    );
  }
}
