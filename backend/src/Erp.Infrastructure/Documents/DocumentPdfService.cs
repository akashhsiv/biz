using Erp.Application.Common;
using Erp.Application.Documents;
using Erp.Domain.Sales;
using Erp.Domain.System;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Documents;

public class DocumentPdfService(ErpDbContext db, IPdfRenderer renderer) : IDocumentPdfService
{
    public async Task<PdfResult> RenderSalesInvoiceAsync(Guid id, CancellationToken ct = default)
    {
        var invoice = await db.SalesInvoices.Include(i => i.Lines).ThenInclude(l => l.Item).Include(i => i.Customer).FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(SalesInvoice), id);

        var settings = await GetSettingsAsync(ct);
        var html = HtmlTemplates.Document(
            "SALES INVOICE", invoice.InvoiceNumber, invoice.CreatedAt, ToShopParty(settings), "Customer",
            ToCustomerParty(invoice.Customer),
            invoice.Lines.Select(ToLine), invoice.Subtotal, invoice.OverallDiscountAmount, invoice.TaxTotal, invoice.GrandTotal,
            [
                new TemplateExtraRow("Deposit Applied", invoice.DepositAllocatedTotal.ToString("0.00")),
                new TemplateExtraRow("Status", invoice.Status.ToString()),
            ],
            ToBankDetails(settings), ToLogoBase64(settings),
            settings.SalesInvoiceTermsAndConditions, settings.SalesInvoiceFooterNote, settings.ShowSignatureBlock,
            ToUpiQrBase64(settings, invoice.GrandTotal), ToSignatureBase64(settings), invoice.PlaceOfSupply);

        return new PdfResult($"{invoice.InvoiceNumber}.pdf", await renderer.RenderAsync(html, ct));
    }

    public async Task<PdfResult> RenderPurchaseOrderAsync(Guid id, CancellationToken ct = default)
    {
        var order = await db.PurchaseOrders.Include(o => o.Lines).ThenInclude(l => l.Item).Include(o => o.Supplier).FirstOrDefaultAsync(o => o.Id == id, ct)
            ?? throw new NotFoundAppException("PurchaseOrder", id);

        var settings = await GetSettingsAsync(ct);
        var lines = order.Lines.Select(l => new TemplateLine(l.Item.Name, l.QuantityOrdered, l.Rate, 0, l.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal, l.Item.HsnCode));

        var html = HtmlTemplates.Document(
            "PURCHASE ORDER", order.PoNumber, order.CreatedAt, ToShopParty(settings), "Supplier",
            new TemplateParty(order.Supplier.Name, order.Supplier.GstNumber, order.Supplier.Address, order.Supplier.ContactNumber, order.Supplier.State),
            lines, order.Subtotal, 0, order.TaxTotal, order.GrandTotal,
            [
                new TemplateExtraRow("Status", order.Status.ToString()),
                new TemplateExtraRow("Payment Status", order.PaymentStatus.ToString()),
            ],
            // No bank details or UPI QR on a Purchase Order — the shop is paying the supplier, not requesting payment.
            bankDetails: null, logoBase64: ToLogoBase64(settings),
            termsAndConditions: settings.PurchaseOrderTermsAndConditions, footerNote: settings.PurchaseOrderFooterNote,
            showSignatureBlock: settings.ShowSignatureBlock,
            signatureBase64: ToSignatureBase64(settings));

        return new PdfResult($"{order.PoNumber}.pdf", await renderer.RenderAsync(html, ct));
    }

    private async Task<CompanySettings> GetSettingsAsync(CancellationToken ct) =>
        await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("Company settings have not been configured.");

    private static TemplateParty ToShopParty(CompanySettings s) => new(s.ShopName, s.Gstin, s.Address, s.ContactNumber, s.State);

    private static TemplateParty ToCustomerParty(Erp.Domain.Customers.Customer c) =>
        new(c.Name, c.GstNumber, c.BillingAddress, c.ContactNumber, c.GstState);

    private static TemplateBankDetails ToBankDetails(CompanySettings s) =>
        new(s.BankName, s.BankAccountNumber, s.BankIfscCode, s.BankBranch);

    private static string? ToLogoBase64(CompanySettings s) =>
        s.ShowLogoOnDocuments && s.Logo is not null ? Convert.ToBase64String(s.Logo) : null;

    private static string? ToSignatureBase64(CompanySettings s) =>
        s.Signature is not null ? Convert.ToBase64String(s.Signature) : null;

    private static string? ToUpiQrBase64(CompanySettings s, decimal amount) =>
        string.IsNullOrWhiteSpace(s.UpiId) ? null : UpiQrCode.GeneratePngBase64(s.UpiId, s.ShopName, amount);

    private static TemplateLine ToLine(DocumentLineBase l) =>
        new(l.Description, l.Quantity, l.Rate, l.Discount, l.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal, l.Item?.HsnCode ?? l.HsnCode);
}
