using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSerialNumbersToDocumentLines : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SerialNumbersCsv",
                table: "sales_invoice_lines",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SerialNumbersCsv",
                table: "quotation_lines",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SerialNumbersCsv",
                table: "proforma_lines",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SerialNumbersCsv",
                table: "sales_invoice_lines");

            migrationBuilder.DropColumn(
                name: "SerialNumbersCsv",
                table: "quotation_lines");

            migrationBuilder.DropColumn(
                name: "SerialNumbersCsv",
                table: "proforma_lines");
        }
    }
}
