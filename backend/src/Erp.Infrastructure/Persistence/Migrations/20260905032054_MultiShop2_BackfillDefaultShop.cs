using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    /// <summary>Data-only migration (multi-shop rework, step 2 of 3): creates one default Company +
    /// Shop from the pre-existing (single-row) company_settings data, backfills ShopId on every
    /// IShopScoped table to that shop, and grants every existing user a UserShopRole in that shop
    /// matching their current (legacy) User.RoleId. Written as idempotent PL/pgSQL so it's safe to
    /// re-run if a deploy is retried. Migration 1 added ShopId as nullable specifically so this step
    /// can run against pre-existing data; migration 3 tightens the columns to NOT NULL afterwards.</summary>
    public partial class MultiShop2_BackfillDefaultShop : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DO $$
                DECLARE
                    default_shop_id uuid;
                    default_company_id uuid;
                    settings_row RECORD;
                BEGIN
                    -- Already backfilled (re-run safety): bail out early.
                    IF EXISTS (SELECT 1 FROM shops LIMIT 1) THEN
                        SELECT "Id" INTO default_shop_id FROM shops ORDER BY "CreatedAt" LIMIT 1;
                    ELSE
                        default_company_id := gen_random_uuid();
                        INSERT INTO companies ("Id", "Name", "CreatedBy", "CreatedAt")
                        VALUES (default_company_id, 'My Company', '00000000-0000-0000-0000-000000000000', now());

                        SELECT "ShopName", "Gstin" INTO settings_row FROM company_settings LIMIT 1;

                        default_shop_id := gen_random_uuid();
                        INSERT INTO shops ("Id", "CompanyId", "Name", "Gstin", "IsActive", "CreatedBy", "CreatedAt")
                        VALUES (
                            default_shop_id,
                            default_company_id,
                            COALESCE(settings_row."ShopName", 'My Shop'),
                            COALESCE(settings_row."Gstin", '00AAAAA0000A1Z5'),
                            true,
                            '00000000-0000-0000-0000-000000000000',
                            now()
                        );
                    END IF;

                    UPDATE audit_logs SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE company_settings SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE customer_deposits SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE customers SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE deposit_allocations SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE document_sequences SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE expenses SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE financial_transactions SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE item_categories SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE items SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE proforma_invoices SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE purchase_orders SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE purchase_receipts SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE quotations SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE return_policies SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE sales_invoices SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE sales_returns SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE stock_movements SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE suppliers SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;
                    UPDATE whatsapp_outbox SET "ShopId" = default_shop_id WHERE "ShopId" IS NULL;

                    -- Every existing user gets their current (legacy) role in the default shop.
                    INSERT INTO user_shop_roles ("Id", "UserId", "ShopId", "RoleId", "CreatedBy", "CreatedAt")
                    SELECT gen_random_uuid(), u."Id", default_shop_id, u."RoleId", '00000000-0000-0000-0000-000000000000', now()
                    FROM users u
                    WHERE NOT EXISTS (
                        SELECT 1 FROM user_shop_roles usr WHERE usr."UserId" = u."Id" AND usr."ShopId" = default_shop_id
                    );
                END $$;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Intentionally not reversed — unwinding a shop assignment safely requires knowing
            // whether any of these rows were re-scoped to a different shop since. Roll back schema
            // migration 1 (which drops the ShopId columns entirely) instead of trying to undo this data step.
        }
    }
}
