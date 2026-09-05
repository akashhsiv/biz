import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/list_screen_shortcuts.dart';
import '../../shared/widgets/report_pdf_export.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void refresh() {
      ref.invalidate(salesReportProvider);
      ref.invalidate(purchaseReportProvider);
      ref.invalidate(lowStockReportProvider);
      ref.invalidate(financeReportProvider);
      ref.invalidate(outstandingReportProvider);
      ref.invalidate(auditReportProvider);
    }

    return ListScreenShortcuts(
      onRefresh: refresh,
      child: DefaultTabController(
        length: 5,
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
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      // Explicit colors, not the app's default TabBarTheme - that theme is tuned for
                      // white-on-dark (the top AppBar), which would be invisible on this white card.
                      labelColor: AppPalette.primary,
                      unselectedLabelColor: AppPalette.textSecondary,
                      indicatorColor: AppPalette.primary,
                      tabs: [
                        Tab(text: 'Sales'),
                        Tab(text: 'Purchase'),
                        Tab(text: 'Low Stock'),
                        Tab(text: 'Finance'),
                        Tab(text: 'Audit'),
                      ],
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(children: [
                  _SalesReportTab(),
                  _PurchaseReportTab(),
                  _LowStockTab(),
                  _FinanceReportTab(),
                  _AuditReportTab(),
                ]),
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

    return SizedBox(
      height: 32.0 * top.length + 16,
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

class _SalesReportTab extends ConsumerWidget {
  const _SalesReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(salesReportProvider);

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
              ('Quotations', '${r['quotationCount']}'),
              ('Proformas', '${r['proformaCount']}'),
            ],
            sections: [
              ReportPdfSection(title: 'By Customer', columns: const ['Customer', 'Total', 'Invoices'], rows: byCustomerRows),
              ReportPdfSection(title: 'By Item', columns: const ['Item', 'Total'], rows: byItemRows),
            ],
          ),
          children: [
            _StatRow([
              _Stat(icon: Icons.point_of_sale_outlined, label: 'Total Sales', value: '₹${(r['totalSales'] as num).toStringAsFixed(2)}', color: AppPalette.success),
              _Stat(icon: Icons.receipt_long_outlined, label: 'Invoices', value: '${r['invoiceCount']}'),
              _Stat(icon: Icons.request_quote_outlined, label: 'Quotations', value: '${r['quotationCount']}'),
              _Stat(icon: Icons.description_outlined, label: 'Proformas', value: '${r['proformaCount']}'),
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

class _PurchaseReportTab extends ConsumerWidget {
  const _PurchaseReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(purchaseReportProvider);

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
