using Erp.Api.Auth;
using Erp.Application.Security;
using Microsoft.AspNetCore.Mvc;

namespace Erp.Api.Controllers;

/// <summary>
/// Exposes the Host's own server-side error log (see ExceptionHandlingMiddleware) so a Shop Admin can
/// read it from any Slave without needing physical/remote access to the Host PC's filesystem.
/// </summary>
[ApiController]
[Route("api/diagnostics")]
public class DiagnosticsController : ControllerBase
{
    private static string LogPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "ErpHost", "logs", "error.log");

    [HttpGet("server-log")]
    [RequirePermission(PermissionKeys.AuditLogsView)]
    public async Task<ActionResult<string>> ServerLog(CancellationToken ct)
    {
        if (!System.IO.File.Exists(LogPath)) return Ok("");
        return Ok(await System.IO.File.ReadAllTextAsync(LogPath, ct));
    }

    [HttpDelete("server-log")]
    [RequirePermission(PermissionKeys.AuditLogsView)]
    public IActionResult ClearServerLog()
    {
        if (System.IO.File.Exists(LogPath)) System.IO.File.Delete(LogPath);
        return NoContent();
    }
}
