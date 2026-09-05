namespace Erp.Application.Documents;

public record PdfResult(string FileName, byte[] Bytes);

/// <summary>Loads a finalized document and renders it to PDF via an HTML template — ARCHITECTURE.md §35. Fully offline once Chromium has been fetched once.</summary>
public interface IDocumentPdfService
{
    Task<PdfResult> RenderQuotationAsync(Guid id, CancellationToken ct = default);
    Task<PdfResult> RenderProformaAsync(Guid id, CancellationToken ct = default);
    Task<PdfResult> RenderSalesInvoiceAsync(Guid id, CancellationToken ct = default);
    Task<PdfResult> RenderPurchaseOrderAsync(Guid id, CancellationToken ct = default);
}
