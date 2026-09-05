namespace Erp.Application.Commission;

/// <summary>
/// Isolated, swappable trigger for commission calculation. Deliberately kept simple and separate
/// from the SalesInvoice creation flow (see QuotationsController.ConvertToSalesInvoiceAsync /
/// ProformasController.Convert) — a business decision on the exact meaning of "commission" can
/// change the calculation formula in this one place without touching invoice creation logic.
/// See CommissionCalculationService for the current (provisional) formula.
/// </summary>
public interface ICommissionCalculationService
{
    /// <summary>
    /// Call once, after a SalesInvoice and its Lines have been added to the DbContext (they do not
    /// need to be saved yet — this only needs their in-memory values plus SalesInvoice.Id, which is
    /// already assigned client-side as a Guid). For each line whose CustomerId+ItemId has an active
    /// CustomerProductRate with a non-null CommissionRate, creates and adds (via db.CommissionEntries.Add)
    /// a Pending CommissionEntry snapshotting the calculated amount. Does not call SaveChanges — the
    /// caller's existing SaveChangesAsync/transaction picks these up along with everything else.
    /// </summary>
    Task CalculateForInvoiceAsync(Erp.Domain.Sales.SalesInvoice invoice, CancellationToken ct = default);
}
