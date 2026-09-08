using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    /// <summary>Hand-edited after scaffolding (mirrors MultiShop3_MakeShopIdRequired's two-step
    /// pattern): sales_invoices already had rows in local dev at the time this was written (0 in
    /// purchase_orders, but treated the same way for consistency), so CategoryId/BrandId can't simply be
    /// added as NOT NULL — Postgres would reject it with no valid value to backfill existing rows with.
    /// Instead: add the document CategoryId columns nullable, ensure every existing shop has a "Cash
    /// Bill" ItemCategory (same name DefaultCategorySeeder.EnsureCashBillCategoryAsync uses at the C#
    /// level — this SQL block exists only because migrations run before any app code, including the
    /// seeder, ever executes), backfill every existing row to that shop's Cash Bill category, then
    /// tighten the columns to NOT NULL and add the FK constraints last (so the FK check only ever sees
    /// fully-backfilled data).</summary>
    public partial class AddBrandVendorBrandAndDocumentCategory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CategoryId",
                table: "sales_invoices",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CategoryId",
                table: "purchase_orders",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "BrandId",
                table: "items",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "brands",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ShopId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    CategoryId = table.Column<Guid>(type: "uuid", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_brands", x => x.Id);
                    table.ForeignKey(
                        name: "FK_brands_item_categories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "item_categories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_brands_shops_ShopId",
                        column: x => x.ShopId,
                        principalTable: "shops",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "vendor_brands",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ShopId = table.Column<Guid>(type: "uuid", nullable: false),
                    SupplierId = table.Column<Guid>(type: "uuid", nullable: false),
                    BrandId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vendor_brands", x => x.Id);
                    table.ForeignKey(
                        name: "FK_vendor_brands_brands_BrandId",
                        column: x => x.BrandId,
                        principalTable: "brands",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_vendor_brands_shops_ShopId",
                        column: x => x.ShopId,
                        principalTable: "shops",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_vendor_brands_suppliers_SupplierId",
                        column: x => x.SupplierId,
                        principalTable: "suppliers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_sales_invoices_CategoryId",
                table: "sales_invoices",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_purchase_orders_CategoryId",
                table: "purchase_orders",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_items_BrandId",
                table: "items",
                column: "BrandId");

            migrationBuilder.CreateIndex(
                name: "IX_brands_CategoryId",
                table: "brands",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_brands_ShopId",
                table: "brands",
                column: "ShopId");

            migrationBuilder.CreateIndex(
                name: "IX_vendor_brands_BrandId",
                table: "vendor_brands",
                column: "BrandId");

            migrationBuilder.CreateIndex(
                name: "IX_vendor_brands_ShopId_SupplierId_BrandId",
                table: "vendor_brands",
                columns: new[] { "ShopId", "SupplierId", "BrandId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_vendor_brands_SupplierId",
                table: "vendor_brands",
                column: "SupplierId");

            migrationBuilder.AddForeignKey(
                name: "FK_items_brands_BrandId",
                table: "items",
                column: "BrandId",
                principalTable: "brands",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            // Backfill step: ensure every existing shop has a "Cash Bill" ItemCategory, then point every
            // existing purchase_orders/sales_invoices row at its own shop's Cash Bill category. Idempotent
            // (safe to re-run): the ItemCategory insert is guarded by a NOT EXISTS check on (ShopId, Name),
            // and the UPDATEs only touch rows where CategoryId IS NULL.
            migrationBuilder.Sql("""
                DO $$
                BEGIN
                    INSERT INTO item_categories ("Id", "ShopId", "Name", "IsActive", "CreatedBy", "CreatedAt")
                    SELECT gen_random_uuid(), s."Id", 'Cash Bill', true, '00000000-0000-0000-0000-000000000000', now()
                    FROM shops s
                    WHERE NOT EXISTS (
                        SELECT 1 FROM item_categories ic WHERE ic."ShopId" = s."Id" AND ic."Name" = 'Cash Bill'
                    );

                    UPDATE purchase_orders po
                    SET "CategoryId" = ic."Id"
                    FROM item_categories ic
                    WHERE po."CategoryId" IS NULL AND ic."ShopId" = po."ShopId" AND ic."Name" = 'Cash Bill';

                    UPDATE sales_invoices si
                    SET "CategoryId" = ic."Id"
                    FROM item_categories ic
                    WHERE si."CategoryId" IS NULL AND ic."ShopId" = si."ShopId" AND ic."Name" = 'Cash Bill';
                END $$;
                """);

            migrationBuilder.AlterColumn<Guid>(
                name: "CategoryId",
                table: "purchase_orders",
                type: "uuid",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "CategoryId",
                table: "sales_invoices",
                type: "uuid",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_purchase_orders_item_categories_CategoryId",
                table: "purchase_orders",
                column: "CategoryId",
                principalTable: "item_categories",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_sales_invoices_item_categories_CategoryId",
                table: "sales_invoices",
                column: "CategoryId",
                principalTable: "item_categories",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_items_brands_BrandId",
                table: "items");

            migrationBuilder.DropForeignKey(
                name: "FK_purchase_orders_item_categories_CategoryId",
                table: "purchase_orders");

            migrationBuilder.DropForeignKey(
                name: "FK_sales_invoices_item_categories_CategoryId",
                table: "sales_invoices");

            migrationBuilder.DropTable(
                name: "vendor_brands");

            migrationBuilder.DropTable(
                name: "brands");

            migrationBuilder.DropIndex(
                name: "IX_sales_invoices_CategoryId",
                table: "sales_invoices");

            migrationBuilder.DropIndex(
                name: "IX_purchase_orders_CategoryId",
                table: "purchase_orders");

            migrationBuilder.DropIndex(
                name: "IX_items_BrandId",
                table: "items");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "sales_invoices");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "purchase_orders");

            migrationBuilder.DropColumn(
                name: "BrandId",
                table: "items");
        }
    }
}
