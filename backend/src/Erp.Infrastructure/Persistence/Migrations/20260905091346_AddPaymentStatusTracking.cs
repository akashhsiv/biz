using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentStatusTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Default true to match ShopNotificationSettings' C# property defaults and existing shops'
            // rows (PurchaseDue/PurchaseOverdue also default enabled) — a shop that never revisits
            // Notification Settings after this migration still gets these new alerts, consistent with
            // how the other event types behave today.
            migrationBuilder.AddColumn<bool>(
                name: "SalesPaymentDueMobile",
                table: "shop_notification_settings",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "SalesPaymentDueWhatsapp",
                table: "shop_notification_settings",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "SalesPaymentOverdueMobile",
                table: "shop_notification_settings",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "SalesPaymentOverdueWhatsapp",
                table: "shop_notification_settings",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DueDate",
                table: "sales_invoices",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "OutstandingTotal",
                table: "sales_invoices",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "PaymentStatus",
                table: "sales_invoices",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "BalancePaymentStatus",
                table: "purchase_orders",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "OutstandingTotal",
                table: "purchase_orders",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            // Backfill OutstandingTotal/PaymentStatus for existing sales_invoices from GrandTotal minus
            // DepositAllocatedTotal (DueDate is null for pre-existing rows, so backdated Overdue never
            // applies here — mirrors DocumentPaymentStatusCalculator's Paid/PartiallyPaid/Credit branches).
            // Cancelled invoices are force-settled to Paid/0, matching SalesInvoicesController.Cancel.
            migrationBuilder.Sql("""
                UPDATE sales_invoices
                SET "OutstandingTotal" = CASE
                        WHEN "Status" = 1 THEN 0
                        ELSE GREATEST("GrandTotal" - "DepositAllocatedTotal", 0)
                    END,
                    "PaymentStatus" = CASE
                        WHEN "Status" = 1 THEN 0
                        WHEN GREATEST("GrandTotal" - "DepositAllocatedTotal", 0) <= 0 THEN 0
                        WHEN GREATEST("GrandTotal" - "DepositAllocatedTotal", 0) < "GrandTotal" THEN 1
                        ELSE 2
                    END;
                """);

            // Backfill OutstandingTotal/BalancePaymentStatus for existing purchase_orders from GrandTotal
            // minus the sum of Completed PurchasePayments. DueDate may already be set on older rows, so
            // Overdue (3) is possible here unlike sales_invoices above.
            migrationBuilder.Sql("""
                UPDATE purchase_orders po
                SET "OutstandingTotal" = CASE
                        WHEN po."Status" = 5 THEN 0
                        ELSE GREATEST(po."GrandTotal" - COALESCE((
                            SELECT SUM(pp."Amount") FROM purchase_payments pp
                            WHERE pp."PurchaseOrderId" = po."Id" AND pp."Status" = 1
                        ), 0), 0)
                    END,
                    "BalancePaymentStatus" = CASE
                        WHEN po."Status" = 5 THEN 0
                        WHEN GREATEST(po."GrandTotal" - COALESCE((
                            SELECT SUM(pp."Amount") FROM purchase_payments pp
                            WHERE pp."PurchaseOrderId" = po."Id" AND pp."Status" = 1
                        ), 0), 0) <= 0 THEN 0
                        WHEN po."DueDate" IS NOT NULL AND po."DueDate" < now() THEN 3
                        WHEN GREATEST(po."GrandTotal" - COALESCE((
                            SELECT SUM(pp."Amount") FROM purchase_payments pp
                            WHERE pp."PurchaseOrderId" = po."Id" AND pp."Status" = 1
                        ), 0), 0) < po."GrandTotal" THEN 1
                        ELSE 2
                    END;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SalesPaymentDueMobile",
                table: "shop_notification_settings");

            migrationBuilder.DropColumn(
                name: "SalesPaymentDueWhatsapp",
                table: "shop_notification_settings");

            migrationBuilder.DropColumn(
                name: "SalesPaymentOverdueMobile",
                table: "shop_notification_settings");

            migrationBuilder.DropColumn(
                name: "SalesPaymentOverdueWhatsapp",
                table: "shop_notification_settings");

            migrationBuilder.DropColumn(
                name: "DueDate",
                table: "sales_invoices");

            migrationBuilder.DropColumn(
                name: "OutstandingTotal",
                table: "sales_invoices");

            migrationBuilder.DropColumn(
                name: "PaymentStatus",
                table: "sales_invoices");

            migrationBuilder.DropColumn(
                name: "BalancePaymentStatus",
                table: "purchase_orders");

            migrationBuilder.DropColumn(
                name: "OutstandingTotal",
                table: "purchase_orders");
        }
    }
}
