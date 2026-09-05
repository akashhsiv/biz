using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCompanySettingsUpiSignatureAndWhatsappTemplates : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "Signature",
                table: "company_settings",
                type: "bytea",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "UpiId",
                table: "company_settings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WhatsappDepositReceiptMessageTemplate",
                table: "company_settings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WhatsappProformaMessageTemplate",
                table: "company_settings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WhatsappQuotationMessageTemplate",
                table: "company_settings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WhatsappSalesInvoiceMessageTemplate",
                table: "company_settings",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Signature",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "UpiId",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "WhatsappDepositReceiptMessageTemplate",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "WhatsappProformaMessageTemplate",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "WhatsappQuotationMessageTemplate",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "WhatsappSalesInvoiceMessageTemplate",
                table: "company_settings");
        }
    }
}
