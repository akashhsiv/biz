using Erp.Domain.Common;
using Erp.Domain.Items;

namespace Erp.Domain.Staff;

public class Staff : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string Name { get; set; } = default!;
    public string EmployeeCode { get; set; } = default!;
    public string? Mobile { get; set; }
    public string? Address { get; set; }
    public DateTime JoiningDate { get; set; }
    public string? Designation { get; set; }

    public Guid? CategoryId { get; set; }
    public ItemCategory? Category { get; set; }

    public StaffEmploymentStatus EmploymentStatus { get; set; } = StaffEmploymentStatus.Active;
    public StaffSalaryType SalaryType { get; set; } = StaffSalaryType.Monthly;

    /// <summary>Current/live rate — used only when generating a NEW SalaryPayment. Editing these
    /// values must never retroactively change an already-generated SalaryPayment; see the
    /// snapshot fields on SalaryPayment (mirrors the DocumentLineBase snapshot convention).</summary>
    public decimal BasicSalary { get; set; }
    public decimal Allowances { get; set; }
    public decimal Deductions { get; set; }

    public string? Notes { get; set; }
    public bool IsActive { get; set; } = true;

    public ICollection<SalaryPayment> SalaryPayments { get; set; } = new List<SalaryPayment>();
}
