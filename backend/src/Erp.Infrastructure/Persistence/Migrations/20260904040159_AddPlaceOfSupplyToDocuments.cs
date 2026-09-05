using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPlaceOfSupplyToDocuments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PlaceOfSupply",
                table: "sales_invoices",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PlaceOfSupply",
                table: "quotations",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PlaceOfSupply",
                table: "proforma_invoices",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PlaceOfSupply",
                table: "sales_invoices");

            migrationBuilder.DropColumn(
                name: "PlaceOfSupply",
                table: "quotations");

            migrationBuilder.DropColumn(
                name: "PlaceOfSupply",
                table: "proforma_invoices");
        }
    }
}
