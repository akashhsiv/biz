using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Erp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDocumentTemplateSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ProformaFooterNote",
                table: "company_settings",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProformaTermsAndConditions",
                table: "company_settings",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PurchaseOrderFooterNote",
                table: "company_settings",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PurchaseOrderTermsAndConditions",
                table: "company_settings",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "QuotationFooterNote",
                table: "company_settings",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "QuotationTermsAndConditions",
                table: "company_settings",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SalesInvoiceFooterNote",
                table: "company_settings",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SalesInvoiceTermsAndConditions",
                table: "company_settings",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "ShowLogoOnDocuments",
                table: "company_settings",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "ShowSignatureBlock",
                table: "company_settings",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ProformaFooterNote",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "ProformaTermsAndConditions",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "PurchaseOrderFooterNote",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "PurchaseOrderTermsAndConditions",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "QuotationFooterNote",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "QuotationTermsAndConditions",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "SalesInvoiceFooterNote",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "SalesInvoiceTermsAndConditions",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "ShowLogoOnDocuments",
                table: "company_settings");

            migrationBuilder.DropColumn(
                name: "ShowSignatureBlock",
                table: "company_settings");
        }
    }
}
