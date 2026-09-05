using Erp.Api.Auth;
using Erp.Application.Backup;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record BackupHistoryDto(Guid Id, string FilePath, long SizeBytes, BackupType BackupType, BackupStatus Status, DateTime CreatedAt);

[ApiController]
[Route("api/backups")]
public class BackupsController(ErpDbContext db, IBackupService backupService, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.BackupManage)]
    public async Task<ActionResult<List<BackupHistoryDto>>> List(CancellationToken ct)
    {
        var backups = await db.BackupHistories.OrderByDescending(b => b.CreatedAt).Take(100)
            .Select(b => new BackupHistoryDto(b.Id, b.FilePath, b.SizeBytes, b.BackupType, b.Status, b.CreatedAt))
            .ToListAsync(ct);

        return Ok(backups);
    }

    [HttpPost("run")]
    [RequirePermission(PermissionKeys.BackupManage)]
    public async Task<ActionResult<BackupHistoryDto>> Run(CancellationToken ct)
    {
        var result = await backupService.RunBackupAsync(BackupType.Manual, currentUser.UserId, ct);
        if (!result.Success)
            return Problem(title: "Backup failed", detail: result.Error, statusCode: 500);

        return Ok(new BackupHistoryDto(result.Id, result.FilePath, result.SizeBytes, BackupType.Manual, BackupStatus.Success, DateTime.UtcNow));
    }
}
