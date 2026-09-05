using Erp.Domain.Staff;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class StaffConfiguration : IEntityTypeConfiguration<Staff>
{
    public void Configure(EntityTypeBuilder<Staff> b)
    {
        b.ToTable("staff");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(200).IsRequired();
        b.Property(x => x.EmployeeCode).HasMaxLength(50).IsRequired();
        b.Property(x => x.Mobile).HasMaxLength(20);
        b.Property(x => x.Designation).HasMaxLength(100);
        b.Property(x => x.BasicSalary).HasPrecision(18, 2);
        b.Property(x => x.Allowances).HasPrecision(18, 2);
        b.Property(x => x.Deductions).HasPrecision(18, 2);

        b.HasIndex(x => new { x.ShopId, x.EmployeeCode }).IsUnique();

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Category).WithMany()
            .HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class SalaryPaymentConfiguration : IEntityTypeConfiguration<SalaryPayment>
{
    public void Configure(EntityTypeBuilder<SalaryPayment> b)
    {
        b.ToTable("salary_payments");
        b.HasKey(x => x.Id);
        b.Property(x => x.BasicSalary).HasPrecision(18, 2);
        b.Property(x => x.Allowance).HasPrecision(18, 2);
        b.Property(x => x.Deduction).HasPrecision(18, 2);
        b.Property(x => x.NetSalary).HasPrecision(18, 2);
        b.Property(x => x.PaidAmount).HasPrecision(18, 2);
        b.Property(x => x.PendingAmount).HasPrecision(18, 2);

        b.HasIndex(x => new { x.StaffId, x.PeriodYear, x.PeriodMonth }).IsUnique();

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Staff).WithMany(x => x.SalaryPayments)
            .HasForeignKey(x => x.StaffId).OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Entries).WithOne(x => x.SalaryPayment)
            .HasForeignKey(x => x.SalaryPaymentId).OnDelete(DeleteBehavior.Cascade);
    }
}

public class SalaryPaymentEntryConfiguration : IEntityTypeConfiguration<SalaryPaymentEntry>
{
    public void Configure(EntityTypeBuilder<SalaryPaymentEntry> b)
    {
        b.ToTable("salary_payment_entries");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.Property(x => x.PaymentMethod).HasMaxLength(50);
    }
}
