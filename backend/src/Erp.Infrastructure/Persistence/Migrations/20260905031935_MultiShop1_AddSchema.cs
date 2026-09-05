using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class MultiShop1_AddSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Expenses_financial_transactions_FinancialTransactionId",
                table: "Expenses");

            migrationBuilder.DropIndex(
                name: "IX_sales_returns_ReturnNumber",
                table: "sales_returns");

            migrationBuilder.DropIndex(
                name: "IX_sales_invoices_InvoiceNumber",
                table: "sales_invoices");

            migrationBuilder.DropIndex(
                name: "IX_quotations_QuotationNumber",
                table: "quotations");

            migrationBuilder.DropIndex(
                name: "IX_purchase_receipts_ReceiptNumber",
                table: "purchase_receipts");

            migrationBuilder.DropIndex(
                name: "IX_purchase_orders_PoNumber",
                table: "purchase_orders");

            migrationBuilder.DropIndex(
                name: "IX_proforma_invoices_ProformaNumber",
                table: "proforma_invoices");

            migrationBuilder.DropIndex(
                name: "IX_items_Sku",
                table: "items");

            migrationBuilder.DropPrimaryKey(
                name: "PK_Expenses",
                table: "Expenses");

            migrationBuilder.DropIndex(
                name: "IX_document_sequences_DocType_FinancialYear",
                table: "document_sequences");

            migrationBuilder.DropIndex(
                name: "IX_customers_CustomerCode",
                table: "customers");

            migrationBuilder.RenameTable(
                name: "Expenses",
                newName: "expenses");

            migrationBuilder.RenameIndex(
                name: "IX_Expenses_FinancialTransactionId",
                table: "expenses",
                newName: "IX_expenses_FinancialTransactionId");

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "whatsapp_outbox",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "suppliers",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "stock_movements",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "sessions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "sales_returns",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "sales_invoices",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "return_policies",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "quotations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "purchase_receipts",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "purchase_orders",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "proforma_invoices",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "items",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "item_categories",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "financial_transactions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Reason",
                table: "expenses",
                type: "character varying(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "text");

            migrationBuilder.AlterColumn<string>(
                name: "Category",
                table: "expenses",
                type: "character varying(100)",
                maxLength: 100,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "text");

            migrationBuilder.AlterColumn<decimal>(
                name: "Amount",
                table: "expenses",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric");

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "expenses",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "document_sequences",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "deposit_allocations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "customers",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "customer_deposits",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "company_settings",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ShopId",
                table: "audit_logs",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddPrimaryKey(
                name: "PK_expenses",
                table: "expenses",
                column: "Id");

            migrationBuilder.CreateTable(
                name: "companies",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_companies", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "shops",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CompanyId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Gstin = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Address = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ContactNumber = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_shops", x => x.Id);
                    table.ForeignKey(
                        name: "FK_shops_companies_CompanyId",
                        column: x => x.CompanyId,
                        principalTable: "companies",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "user_shop_roles",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ShopId = table.Column<Guid>(type: "uuid", nullable: false),
                    RoleId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_shop_roles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_user_shop_roles_roles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "roles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_user_shop_roles_shops_ShopId",
                        column: x => x.ShopId,
                        principalTable: "shops",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_user_shop_roles_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_whatsapp_outbox_ShopId",
                table: "whatsapp_outbox",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_suppliers_ShopId",
                table: "suppliers",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_stock_movements_ShopId",
                table: "stock_movements",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_sessions_ShopId",
                table: "sessions",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_sales_returns_ShopId_ReturnNumber",
                table: "sales_returns",
                columns: new[] { "ShopId", "ReturnNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_sales_invoices_ShopId_InvoiceNumber",
                table: "sales_invoices",
                columns: new[] { "ShopId", "InvoiceNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_return_policies_ShopId",
                table: "return_policies",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_quotations_ShopId_QuotationNumber",
                table: "quotations",
                columns: new[] { "ShopId", "QuotationNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_purchase_receipts_ShopId_ReceiptNumber",
                table: "purchase_receipts",
                columns: new[] { "ShopId", "ReceiptNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_purchase_orders_ShopId_PoNumber",
                table: "purchase_orders",
                columns: new[] { "ShopId", "PoNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_proforma_invoices_ShopId_ProformaNumber",
                table: "proforma_invoices",
                columns: new[] { "ShopId", "ProformaNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_items_ShopId_Sku",
                table: "items",
                columns: new[] { "ShopId", "Sku" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_item_categories_ShopId",
                table: "item_categories",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_financial_transactions_ShopId",
                table: "financial_transactions",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_expenses_ShopId_CreatedAt",
                table: "expenses",
                columns: new[] { "ShopId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_document_sequences_ShopId_DocType_FinancialYear",
                table: "document_sequences",
                columns: new[] { "ShopId", "DocType", "FinancialYear" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_deposit_allocations_ShopId",
                table: "deposit_allocations",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_customers_ShopId_CustomerCode",
                table: "customers",
                columns: new[] { "ShopId", "CustomerCode" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_customer_deposits_ShopId",
                table: "customer_deposits",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_company_settings_ShopId",
                table: "company_settings",
                column: "ShopId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_audit_logs_ShopId",
                table: "audit_logs",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_shops_CompanyId",
                table: "shops",
                column: "CompanyId");

            migrationBuilder.CreateIndex(
                name: "IX_shops_Gstin",
                table: "shops",
                column: "Gstin");

            migrationBuilder.CreateIndex(
                name: "IX_user_shop_roles_RoleId",
                table: "user_shop_roles",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "IX_user_shop_roles_ShopId",
                table: "user_shop_roles",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_user_shop_roles_UserId_ShopId",
                table: "user_shop_roles",
                columns: new[] { "UserId", "ShopId" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_audit_logs_shops_ShopId",
                table: "audit_logs",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_company_settings_shops_ShopId",
                table: "company_settings",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_customer_deposits_shops_ShopId",
                table: "customer_deposits",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_customers_shops_ShopId",
                table: "customers",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_deposit_allocations_shops_ShopId",
                table: "deposit_allocations",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_document_sequences_shops_ShopId",
                table: "document_sequences",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_expenses_financial_transactions_FinancialTransactionId",
                table: "expenses",
                column: "FinancialTransactionId",
                principalTable: "financial_transactions",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_expenses_shops_ShopId",
                table: "expenses",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_financial_transactions_shops_ShopId",
                table: "financial_transactions",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_item_categories_shops_ShopId",
                table: "item_categories",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_items_shops_ShopId",
                table: "items",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_proforma_invoices_shops_ShopId",
                table: "proforma_invoices",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_purchase_orders_shops_ShopId",
                table: "purchase_orders",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_purchase_receipts_shops_ShopId",
                table: "purchase_receipts",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_quotations_shops_ShopId",
                table: "quotations",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_return_policies_shops_ShopId",
                table: "return_policies",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_sales_invoices_shops_ShopId",
                table: "sales_invoices",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_sales_returns_shops_ShopId",
                table: "sales_returns",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_sessions_shops_ShopId",
                table: "sessions",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_stock_movements_shops_ShopId",
                table: "stock_movements",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_suppliers_shops_ShopId",
                table: "suppliers",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_whatsapp_outbox_shops_ShopId",
                table: "whatsapp_outbox",
                column: "ShopId",
                principalTable: "shops",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_audit_logs_shops_ShopId",
                table: "audit_logs");

            migrationBuilder.DropForeignKey(
                name: "FK_company_settings_shops_ShopId",
                table: "company_settings");

            migrationBuilder.DropForeignKey(
                name: "FK_customer_deposits_shops_ShopId",
                table: "customer_deposits");

            migrationBuilder.DropForeignKey(
                name: "FK_customers_shops_ShopId",
                table: "customers");

            migrationBuilder.DropForeignKey(
                name: "FK_deposit_allocations_shops_ShopId",
                table: "deposit_allocations");

            migrationBuilder.DropForeignKey(
                name: "FK_document_sequences_shops_ShopId",
                table: "document_sequences");

            migrationBuilder.DropForeignKey(
                name: "FK_expenses_financial_transactions_FinancialTransactionId",
                table: "expenses");

            migrationBuilder.DropForeignKey(
                name: "FK_expenses_shops_ShopId",
                table: "expenses");

            migrationBuilder.DropForeignKey(
                name: "FK_financial_transactions_shops_ShopId",
                table: "financial_transactions");

            migrationBuilder.DropForeignKey(
                name: "FK_item_categories_shops_ShopId",
                table: "item_categories");

            migrationBuilder.DropForeignKey(
                name: "FK_items_shops_ShopId",
                table: "items");

            migrationBuilder.DropForeignKey(
                name: "FK_proforma_invoices_shops_ShopId",
                table: "proforma_invoices");

            migrationBuilder.DropForeignKey(
                name: "FK_purchase_orders_shops_ShopId",
                table: "purchase_orders");

            migrationBuilder.DropForeignKey(
                name: "FK_purchase_receipts_shops_ShopId",
                table: "purchase_receipts");

            migrationBuilder.DropForeignKey(
                name: "FK_quotations_shops_ShopId",
                table: "quotations");

            migrationBuilder.DropForeignKey(
                name: "FK_return_policies_shops_ShopId",
                table: "return_policies");

            migrationBuilder.DropForeignKey(
                name: "FK_sales_invoices_shops_ShopId",
                table: "sales_invoices");

            migrationBuilder.DropForeignKey(
                name: "FK_sales_returns_shops_ShopId",
                table: "sales_returns");

            migrationBuilder.DropForeignKey(
                name: "FK_sessions_shops_ShopId",
                table: "sessions");

            migrationBuilder.DropForeignKey(
                name: "FK_stock_movements_shops_ShopId",
                table: "stock_movements");

            migrationBuilder.DropForeignKey(
                name: "FK_suppliers_shops_ShopId",
                table: "suppliers");

            migrationBuilder.DropForeignKey(
                name: "FK_whatsapp_outbox_shops_ShopId",
                table: "whatsapp_outbox");

            migrationBuilder.DropTable(
                name: "user_shop_roles");

            migrationBuilder.DropTable(
                name: "shops");

            migrationBuilder.DropTable(
                name: "companies");

            migrationBuilder.DropIndex(
                name: "IX_whatsapp_outbox_ShopId",
                table: "whatsapp_outbox");

            migrationBuilder.DropIndex(
                name: "IX_suppliers_ShopId",
                table: "suppliers");

            migrationBuilder.DropIndex(
                name: "IX_stock_movements_ShopId",
                table: "stock_movements");

            migrationBuilder.DropIndex(
                name: "IX_sessions_ShopId",
                table: "sessions");

            migrationBuilder.DropIndex(
                name: "IX_sales_returns_ShopId_ReturnNumber",
                table: "sales_returns");

            migrationBuilder.DropIndex(
                name: "IX_sales_invoices_ShopId_InvoiceNumber",
                table: "sales_invoices");

            migrationBuilder.DropIndex(
                name: "IX_return_policies_ShopId",
                table: "return_policies");

            migrationBuilder.DropIndex(
                name: "IX_quotations_ShopId_QuotationNumber",
                table: "quotations");

            migrationBuilder.DropIndex(
                name: "IX_purchase_receipts_ShopId_ReceiptNumber",
                table: "purchase_receipts");

            migrationBuilder.DropIndex(
                name: "IX_purchase_orders_ShopId_PoNumber",
                table: "purchase_orders");

            migrationBuilder.DropIndex(
                name: "IX_proforma_invoices_ShopId_ProformaNumber",
                table: "proforma_invoices");

            migrationBuilder.DropIndex(
                name: "IX_items_ShopId_Sku",
                table: "items");

            migrationBuilder.DropIndex(
                name: "IX_item_categories_ShopId",
                table: "item_categories");

            migrationBuilder.DropIndex(
                name: "IX_financial_transactions_ShopId",
                table: "financial_transactions");

            migrationBuilder.DropPrimaryKey(
                name: "PK_expenses",
                table: "expenses");

            migrationBuilder.DropIndex(
                name: "IX_expenses_ShopId_CreatedAt",
                table: "expenses");

            migrationBuilder.DropIndex(
                name: "IX_document_sequences_ShopId_DocType_FinancialYear",
                table: "document_sequences");

            migrationBuilder.DropIndex(
                name: "IX_deposit_allocations_ShopId",
                table: "deposit_allocations");

            migrationBuilder.DropIndex(
                name: "IX_customers_ShopId_CustomerCode",
                table: "customers");

            migrationBuilder.DropIndex(
                name: "IX_customer_deposits_ShopId",
                table: "customer_deposits");

            migrationBuilder.DropIndex(
                name: "IX_company_settings_ShopId",
                table: "company_settings");

            migrationBuilder.DropIndex(
                name: "IX_audit_logs_ShopId",
                table: "audit_logs");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "whatsapp_outbox");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "suppliers");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "stock_movements");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "sessions");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "sales_returns");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "sales_invoices");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "return_policies");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "quotations");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "purchase_receipts");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "purchase_orders");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "proforma_invoices");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "items");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "item_categories");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "financial_transactions");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "expenses");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "document_sequences");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "deposit_allocations");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "customers");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "customer_deposits");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "ShopId",
                table: "audit_logs");

            migrationBuilder.RenameTable(
                name: "expenses",
                newName: "Expenses");

            migrationBuilder.RenameIndex(
                name: "IX_expenses_FinancialTransactionId",
                table: "Expenses",
                newName: "IX_Expenses_FinancialTransactionId");

            migrationBuilder.AlterColumn<string>(
                name: "Reason",
                table: "Expenses",
                type: "text",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(500)",
                oldMaxLength: 500);

            migrationBuilder.AlterColumn<string>(
                name: "Category",
                table: "Expenses",
                type: "text",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "character varying(100)",
                oldMaxLength: 100);

            migrationBuilder.AlterColumn<decimal>(
                name: "Amount",
                table: "Expenses",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldPrecision: 18,
                oldScale: 2);

            migrationBuilder.AddPrimaryKey(
                name: "PK_Expenses",
                table: "Expenses",
                column: "Id");

            migrationBuilder.CreateIndex(
                name: "IX_sales_returns_ReturnNumber",
                table: "sales_returns",
                column: "ReturnNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_sales_invoices_InvoiceNumber",
                table: "sales_invoices",
                column: "InvoiceNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_quotations_QuotationNumber",
                table: "quotations",
                column: "QuotationNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_purchase_receipts_ReceiptNumber",
                table: "purchase_receipts",
                column: "ReceiptNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_purchase_orders_PoNumber",
                table: "purchase_orders",
                column: "PoNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_proforma_invoices_ProformaNumber",
                table: "proforma_invoices",
                column: "ProformaNumber",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_items_Sku",
                table: "items",
                column: "Sku",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_document_sequences_DocType_FinancialYear",
                table: "document_sequences",
                columns: new[] { "DocType", "FinancialYear" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_customers_CustomerCode",
                table: "customers",
                column: "CustomerCode",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Expenses_financial_transactions_FinancialTransactionId",
                table: "Expenses",
                column: "FinancialTransactionId",
                principalTable: "financial_transactions",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
