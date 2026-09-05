using Erp.Domain.Common;

namespace Erp.Domain.Staff;

/// <summary>One staff member's salary record for a given month/year. BasicSalary/Allowance/Deduction/
/// NetSalary are SNAPSHOTS taken from Staff at generation time (mirrors the "snapshot, don't reference
/// live values" convention documented on DocumentLineBase) — editing Staff's rates afterwards must
/// never change an already-generated SalaryPayment.</summary>
public class SalaryPayment : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid StaffId { get; set; }
    public Staff Staff { get; set; } = default!;

    public int PeriodMonth { get; set; }
    public int PeriodYear { get; set; }

    public decimal BasicSalary { get; set; }
    public decimal Allowance { get; set; }
    public decimal Deduction { get; set; }
    public decimal NetSalary { get; set; }

    public decimal PaidAmount { get; set; }
    public decimal PendingAmount { get; set; }
    public SalaryPaymentStatus Status { get; set; } = SalaryPaymentStatus.Pending;

    public ICollection<SalaryPaymentEntry> Entries { get; set; } = new List<SalaryPaymentEntry>();
}
