using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Finance;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Domain.Finance;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record CreateExpenseRequest(string Category, decimal Amount, string Reason, string? PaymentMethod);
public record ExpenseDto(Guid Id, string Category, decimal Amount, string Reason, string? PaymentMethod, DateTime CreatedAt);

[ApiController]
[Route("api/expenses")]
public class ExpensesController(ErpDbContext db, IFinanceLedgerService ledger, IAuditService audit) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.ExpensesManage)]
    public async Task<ActionResult<List<ExpenseDto>>> List([FromQuery] string? category, CancellationToken ct)
    {
        var query = db.Expenses.AsQueryable();
        if (!string.IsNullOrWhiteSpace(category)) query = query.Where(e => e.Category == category);

        var expenses = await query.OrderByDescending(e => e.CreatedAt).ToListAsync(ct);
        return Ok(expenses.Select(ToDto));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.ExpensesManage)]
    public async Task<ActionResult<ExpenseDto>> Create(CreateExpenseRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Category)) throw new ValidationAppException("Category is required.");
        if (request.Amount <= 0) throw new ValidationAppException("Amount must be positive.");
        if (string.IsNullOrWhiteSpace(request.Reason)) throw new ValidationAppException("Reason is required.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var transactionId = await ledger.RecordAmountOutAsync(request.Amount, request.Reason, DocumentReferenceType.Expense, null, ct);

        var expense = new Expense
        {
            Category = request.Category.Trim(),
            Amount = request.Amount,
            Reason = request.Reason.Trim(),
            PaymentMethod = request.PaymentMethod,
            FinancialTransactionId = transactionId,
        };
        db.Expenses.Add(expense);

        // The FinancialTransaction's ReferenceId can't point at the Expense until the Expense itself
        // has an id assigned (it already does, via the default Guid.NewGuid() - but the transaction
        // row was created by RecordAmountOutAsync above without it, since Expense didn't exist yet).
        // RecordAmountOutAsync only adds the transaction to the change tracker - it isn't in the
        // database yet, so it must be found via Local, not a query (which would hit the DB and find
        // nothing, throwing "Sequence contains no elements").
        var transaction = db.FinancialTransactions.Local.First(t => t.Id == transactionId);
        transaction.ReferenceId = expense.Id;

        await audit.LogAsync("expense.created", nameof(Expense), expense.Id, newValue: request, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return Ok(ToDto(expense));
    }

    private static ExpenseDto ToDto(Expense e) => new(e.Id, e.Category, e.Amount, e.Reason, e.PaymentMethod, e.CreatedAt);
}
