using Erp.Domain.Common;

namespace Erp.Domain.System;

public class BackupHistory
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string FilePath { get; set; } = default!;
    public long SizeBytes { get; set; }
    public BackupType BackupType { get; set; }
    public BackupStatus Status { get; set; }
    public Guid? TriggeredBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
