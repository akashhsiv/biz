using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ReplaceItemTaxGroupWithRateAndHsn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_items_tax_groups_TaxGroupId",
                table: "items");

            migrationBuilder.DropIndex(
                name: "IX_items_TaxGroupId",
                table: "items");

            migrationBuilder.DropColumn(
                name: "TaxGroupId",
                table: "items");

            migrationBuilder.AddColumn<string>(
                name: "HsnCode",
                table: "items",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "TaxRatePercent",
                table: "items",
                type: "numeric(5,2)",
                precision: 5,
                scale: 2,
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "HsnCode",
                table: "items");

            migrationBuilder.DropColumn(
                name: "TaxRatePercent",
                table: "items");

            migrationBuilder.AddColumn<Guid>(
                name: "TaxGroupId",
                table: "items",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_items_TaxGroupId",
                table: "items",
                column: "TaxGroupId");

            migrationBuilder.AddForeignKey(
                name: "FK_items_tax_groups_TaxGroupId",
                table: "items",
                column: "TaxGroupId",
                principalTable: "tax_groups",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
