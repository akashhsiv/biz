using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHsnCodeToDocumentLines : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "HsnCode",
                table: "sales_invoice_lines",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "HsnCode",
                table: "quotation_lines",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "HsnCode",
                table: "proforma_lines",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "HsnCode",
                table: "sales_invoice_lines");

            migrationBuilder.DropColumn(
                name: "HsnCode",
                table: "quotation_lines");

            migrationBuilder.DropColumn(
                name: "HsnCode",
                table: "proforma_lines");
        }
    }
}
