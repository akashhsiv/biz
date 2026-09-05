using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    /// <summary>Step 3 of 3 (multi-shop rework): tightens every ShopId column added nullable in
    /// MultiShop1_AddSchema — and backfilled in MultiShop2_BackfillDefaultShop — to NOT NULL. Written
    /// by hand rather than scaffolded: the C# model already declared ShopId as a required Guid back in
    /// migration 1, so `dotnet ef migrations add` sees no model diff at this point and scaffolds an
    /// empty migration; the actual DB-side tightening has to be spelled out explicitly here. Deliberately
    /// excludes `sessions`.ShopId, which stays nullable (set only once a session calls select-shop).</summary>
    public partial class MultiShop3_MakeShopIdRequired : Migration
    {
        private static readonly string[] Tables =
        [
            "company_settings", "customer_deposits", "customers", "deposit_allocations",
            "document_sequences", "expenses", "financial_transactions", "item_categories", "items",
            "proforma_invoices", "purchase_orders", "purchase_receipts", "quotations", "return_policies",
            "sales_invoices", "sales_returns", "stock_movements", "suppliers", "whatsapp_outbox",
        ];

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            foreach (var table in Tables)
            {
                migrationBuilder.AlterColumn<Guid>(
                    name: "ShopId",
                    table: table,
                    type: "uuid",
                    nullable: false,
                    oldClrType: typeof(Guid),
                    oldType: "uuid",
                    oldNullable: true);
            }
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            foreach (var table in Tables)
            {
                migrationBuilder.AlterColumn<Guid>(
                    name: "ShopId",
                    table: table,
                    type: "uuid",
                    nullable: true,
                    oldClrType: typeof(Guid),
                    oldType: "uuid");
            }
        }
    }
}
