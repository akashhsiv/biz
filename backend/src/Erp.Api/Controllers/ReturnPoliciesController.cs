using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Sales;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record ReturnPolicyDto(Guid Id, string Name, Guid? CategoryId, int ReturnWindowDays, decimal RestockingFeePercent, bool IsActive);
public record UpsertReturnPolicyRequest(string Name, Guid? CategoryId, int ReturnWindowDays, decimal RestockingFeePercent);

[ApiController]
[Route("api/return-policies")]
public class ReturnPoliciesController(ErpDbContext db) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.SalesReturnsRequest)]
    public async Task<ActionResult<List<ReturnPolicyDto>>> List(CancellationToken ct) =>
        Ok(await db.ReturnPolicies.Where(p => p.IsActive)
            .Select(p => new ReturnPolicyDto(p.Id, p.Name, p.CategoryId, p.ReturnWindowDays, p.RestockingFeePercent, p.IsActive))
            .ToListAsync(ct));

    [HttpPost]
    [RequirePermission(PermissionKeys.ReturnPoliciesManage)]
    public async Task<ActionResult<ReturnPolicyDto>> Create(UpsertReturnPolicyRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationAppException("Return policy name is required.");

        var policy = new ReturnPolicy
        {
            Name = request.Name,
            CategoryId = request.CategoryId,
            ReturnWindowDays = request.ReturnWindowDays,
            RestockingFeePercent = request.RestockingFeePercent,
            IsActive = true,
        };

        db.ReturnPolicies.Add(policy);
        await db.SaveChangesAsync(ct);

        return Ok(new ReturnPolicyDto(policy.Id, policy.Name, policy.CategoryId, policy.ReturnWindowDays, policy.RestockingFeePercent, policy.IsActive));
    }

    [HttpPost("{id:guid}/deactivate")]
    [RequirePermission(PermissionKeys.ReturnPoliciesManage)]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken ct)
    {
        var policy = await db.ReturnPolicies.FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(ReturnPolicy), id);

        policy.IsActive = false;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }
}
