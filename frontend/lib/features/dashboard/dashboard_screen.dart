import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_list_card.dart';
import '../../shared/widgets/kpi_card.dart';
import '../customers/customers_provider.dart';
import '../finance/deposits_provider.dart';
import '../finance/finance_provider.dart';
import '../quotations/quotation_model.dart';
import '../quotations/quotations_provider.dart';
import '../reports/reports_provider.dart';
import '../sales/sales_invoice_model.dart';
import '../sales/sales_invoices_provider.dart';

const _recentCount = 5;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final salesReport = ref.watch(salesReportProvider(const PaymentStatusReportFilter()));
    final lowStock = ref.watch(lowStockReportProvider);
    final balance = ref.watch(shopBalanceProvider);

    void refresh() {
      ref.invalidate(salesReportProvider);
      ref.invalidate(lowStockReportProvider);
      ref.invalidate(shopBalanceProvider);
      ref.invalidate(quotationsProvider);
      ref.invalidate(salesInvoicesProvider);
      ref.invalidate(depositsProvider);
    }

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, ${auth.fullName}', style: Theme.of(context).textTheme.headlineSmall),
                      Text(auth.roleName, style: TextStyle(color: AppPalette.textMuted)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: refresh),
              ],
            ),
            const SizedBox(height: 20),
            KpiRow(cards: [
              KpiCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Shop Balance',
                value: balance.when(
                  data: (v) => v == null ? '—' : '₹${v.toStringAsFixed(2)}',
                  loading: () => '…',
                  error: (_, _) => '—',
                ),
                caption: 'Current',
              ),
              KpiCard(
                icon: Icons.point_of_sale_outlined,
                label: "Today's Sales",
                value: salesReport.when(
                  data: (v) => v == null ? '—' : '₹${(v['totalSales'] as num? ?? 0).toStringAsFixed(2)}',
                  loading: () => '…',
                  error: (_, _) => '—',
                ),
                accentColor: AppPalette.success,
              ),
              KpiCard(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                value: salesReport.when(
                  data: (v) => v == null ? '—' : '${v['invoiceCount'] ?? 0}',
                  loading: () => '…',
                  error: (_, _) => '—',
                ),
                caption: 'Today',
                accentColor: AppPalette.primaryDark,
              ),
              KpiCard(
                icon: Icons.warning_amber_rounded,
                label: 'Low Stock Items',
                value: lowStock.when(
                  data: (v) => '${v?.length ?? 0}',
                  loading: () => '…',
                  error: (_, _) => '—',
                ),
                accentColor: (lowStock.valueOrNull?.isNotEmpty ?? false) ? AppPalette.error : AppPalette.textMuted,
              ),
            ]),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final showQuotations = auth.has(Permissions.quotationsManage);
                final showInvoices = auth.has(Permissions.salesInvoicesManage);
                final showDeposits = auth.has(Permissions.customerDepositsRecord) || auth.has(Permissions.financeShopBalanceView);
                final wide = constraints.maxWidth > 900;
                final cards = [
                  if (showQuotations) const _RecentQuotationsCard(),
                  if (showInvoices) const _RecentInvoicesCard(),
                  if (showDeposits) const _RecentDepositsCard(),
                ];
                if (cards.isEmpty) return const SizedBox.shrink();

                if (!wide) {
                  return Column(children: [for (final c in cards) ...[c, const SizedBox(height: 16)]]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentQuotationsCard extends ConsumerWidget {
  const _RecentQuotationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotationsAsync = ref.watch(quotationsProvider);
    final customersAsync = ref.watch(customersProvider);
    final nameOf = {for (final c in customersAsync.valueOrNull ?? []) c.id: c.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Recent Quotations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        quotationsAsync.when(
          data: (all) {
            final recent = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final items = recent.take(_recentCount).toList();
            return AppListCard(
              shrinkWrap: true,
              emptyMessage: 'No quotations yet.',
              emptyIcon: Icons.request_quote_outlined,
              columns: const [
                AppListColumn('Number', flex: 3),
                AppListColumn('Customer', flex: 3),
                AppListColumn('Status', flex: 2),
                AppListColumn('Amount', flex: 2, numeric: true),
              ],
              itemCount: items.length,
              cellsBuilder: (context, i) {
                final q = items[i];
                return [
                  Text(q.quotationNumber, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(nameOf[q.customerId] ?? '-', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  _quotationStatusPill(q.status),
                  Text('₹${q.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ];
              },
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load quotations: $e'))),
        ),
      ],
    );
  }
}

Widget _quotationStatusPill(QuotationStatus status) => switch (status) {
      QuotationStatus.draft => StatusPill.draft('Draft'),
      QuotationStatus.issued => StatusPill.info('Issued'),
      QuotationStatus.converted => StatusPill.converted('Converted'),
      QuotationStatus.cancelled => StatusPill.cancelled('Cancelled'),
      QuotationStatus.expired => StatusPill.warning('Expired'),
    };

class _RecentInvoicesCard extends ConsumerWidget {
  const _RecentInvoicesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(salesInvoicesProvider);
    final customersAsync = ref.watch(customersProvider);
    final nameOf = {for (final c in customersAsync.valueOrNull ?? []) c.id: c.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Recent Sales Invoices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        invoicesAsync.when(
          data: (all) {
            final recent = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final items = recent.take(_recentCount).toList();
            return AppListCard(
              shrinkWrap: true,
              emptyMessage: 'No sales invoices yet.',
              emptyIcon: Icons.receipt_long_outlined,
              columns: const [
                AppListColumn('Number', flex: 3),
                AppListColumn('Customer', flex: 3),
                AppListColumn('Status', flex: 2),
                AppListColumn('Amount', flex: 2, numeric: true),
              ],
              itemCount: items.length,
              cellsBuilder: (context, i) {
                final inv = items[i];
                return [
                  Text(inv.invoiceNumber, style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(nameOf[inv.customerId] ?? '-', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  inv.status == SalesInvoiceStatus.active ? StatusPill.success('Active') : StatusPill.cancelled('Cancelled'),
                  Text('₹${inv.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ];
              },
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load invoices: $e'))),
        ),
      ],
    );
  }
}

class _RecentDepositsCard extends ConsumerWidget {
  const _RecentDepositsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositsAsync = ref.watch(depositsProvider(null));
    final customersAsync = ref.watch(customersProvider);
    final nameOf = {for (final c in customersAsync.valueOrNull ?? []) c.id: c.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Recent Payments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        depositsAsync.when(
          data: (all) {
            final recent = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final items = recent.take(_recentCount).toList();
            return AppListCard(
              shrinkWrap: true,
              emptyMessage: 'No payments recorded yet.',
              emptyIcon: Icons.savings_outlined,
              columns: const [
                AppListColumn('Customer', flex: 3),
                AppListColumn('Method', flex: 2),
                AppListColumn('Amount', flex: 2, numeric: true),
              ],
              itemCount: items.length,
              cellsBuilder: (context, i) {
                final d = items[i];
                return [
                  Text(nameOf[d.customerId] ?? '-', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(d.paymentMethod ?? '-', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
                  Text('₹${d.amount.toStringAsFixed(2)}', style: const TextStyle(color: AppPalette.success, fontWeight: FontWeight.w600, fontSize: 13)),
                ];
              },
            );
          },
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load payments: $e'))),
        ),
      ],
    );
  }
}
