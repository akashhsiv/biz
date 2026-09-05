using Erp.Application.Common;
using Erp.Application.Documents;
using Erp.Domain.Sales;
using Erp.Domain.System;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Documents;

public class DocumentPdfService(ErpDbContext db, IPdfRenderer renderer) : IDocumentPdfService
{
    public async Task<PdfResult> RenderQuotationAsync(Guid id, CancellationToken ct = default)
    {
        var quotation = await db.Quotations.Include(q => q.Lines).ThenInclude(l => l.Item).Include(q => q.Customer).FirstOrDefaultAsync(q => q.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Quotation), id);

        var settings = await GetSettingsAsync(ct);
        var html = HtmlTemplates.Document(
            "QUOTATION", quotation.QuotationNumber, quotation.CreatedAt, ToShopParty(settings), "Customer",
            ToCustomerParty(quotation.Customer),
            quotation.Lines.Select(ToLine), quotation.Subtotal, quotation.OverallDiscountAmount, quotation.TaxTotal, quotation.GrandTotal,
            [new TemplateExtraRow("Status", quotation.Status.ToString())],
            ToBankDetails(settings), ToLogoBase64(settings),
            // A per-quotation Notes value (payment terms, delivery notes, special instructions) is
            // shown in its own "Notes" box, separate from the shop-wide default Terms & Conditions -
            // they used to be concatenated into one block, which read as a single undifferentiated
            // wall of text with no indication which part was document-specific.
            settings.QuotationTermsAndConditions, settings.QuotationFooterNote, settings.ShowSignatureBlock,
            ToUpiQrBase64(settings, quotation.GrandTotal), ToSignatureBase64(settings), quotation.PlaceOfSupply, quotation.Notes);

        return new PdfResult($"{quotation.QuotationNumber}.pdf", await renderer.RenderAsync(html, ct));
    }

    public async Task<PdfResult> RenderProformaAsync(Guid id, CancellationToken ct = default)
    {
        var proforma = await db.ProformaInvoices.Include(p => p.Lines).ThenInclude(l => l.Item).Include(p => p.Customer).FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(ProformaInvoice), id);

        var settings = await GetSettingsAsync(ct);
        var html = HtmlTemplates.Document(
            "PROFORMA INVOICE", proforma.ProformaNumber, proforma.CreatedAt, ToShopParty(settings), "Customer",
            ToCustomerParty(proforma.Customer),
            proforma.Lines.Select(ToLine), proforma.Subtotal, proforma.OverallDiscountAmount, proforma.TaxTotal, proforma.GrandTotal,
            [
                new TemplateExtraRow("Deposit Allocated", proforma.AllocatedTotal.ToString("0.00")),
                new TemplateExtraRow("Outstanding", proforma.OutstandingTotal.ToString("0.00")),
                new TemplateExtraRow("Status", proforma.Status.ToString()),
            ],
            ToBankDetails(settings), ToLogoBase64(settings),
            settings.ProformaTermsAndConditions, settings.ProformaFooterNote, settings.ShowSignatureBlock,
            ToUpiQrBase64(settings, proforma.GrandTotal), ToSignatureBase64(settings), proforma.PlaceOfSupply);

        return new PdfResult($"{proforma.ProformaNumber}.pdf", await renderer.RenderAsync(html, ct));
    }

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
