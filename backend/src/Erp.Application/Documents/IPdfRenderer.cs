namespace Erp.Application.Documents;

/// <summary>Backend-only HTML-to-PDF rendering — see ARCHITECTURE.md §9/§35. Flutter never generates the authoritative document.</summary>
public interface IPdfRenderer
{
    Task<byte[]> RenderAsync(string html, CancellationToken ct = default);
}
