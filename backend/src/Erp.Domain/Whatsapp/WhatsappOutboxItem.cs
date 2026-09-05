using Erp.Domain.Common;

namespace Erp.Domain.Whatsapp;

/// <summary>Queued only when Admin explicitly clicks "Send via WhatsApp" (manual trigger, confirmed business rule) — never auto-queued on document creation. Consumed by a background worker independent of the transaction that created the referenced document.</summary>
public class WhatsappOutboxItem
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public WhatsappMessageType MessageType { get; set; }
    public DocumentReferenceType ReferenceType { get; set; }
    public Guid ReferenceId { get; set; }

    public string RecipientNumber { get; set; } = default!;
    public string PayloadJson { get; set; } = default!;

    public WhatsappOutboxStatus Status { get; set; } = WhatsappOutboxStatus.Queued;
    public int Attempts { get; set; }
    public string? LastError { get; set; }
    public DateTime? SentAt { get; set; }

    public Guid CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
