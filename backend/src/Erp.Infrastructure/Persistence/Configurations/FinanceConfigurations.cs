using Erp.Domain.Finance;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class FinancialTransactionConfiguration : IEntityTypeConfiguration<FinancialTransaction>
{
    public void Configure(EntityTypeBuilder<FinancialTransaction> b)
    {
        b.ToTable("financial_transactions");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);

        b.HasIndex(x => new { x.CustomerId, x.CreatedAt });
        b.HasIndex(x => new { x.TransactionType, x.CreatedAt });

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class CustomerDepositConfiguration : IEntityTypeConfiguration<CustomerDeposit>
{
    public void Configure(EntityTypeBuilder<CustomerDeposit> b)
    {
        b.ToTable("customer_deposits");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);

        b.HasIndex(x => new { x.CustomerId, x.CreatedAt });

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.FinancialTransaction).WithMany()
            .HasForeignKey(x => x.FinancialTransactionId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class DepositAllocationConfiguration : IEntityTypeConfiguration<DepositAllocation>
{
    public void Configure(EntityTypeBuilder<DepositAllocation> b)
    {
        b.ToTable("deposit_allocations");
        b.HasKey(x => x.Id);
        b.Property(x => x.AmountAllocated).HasPrecision(18, 2);

        b.HasIndex(x => x.CustomerId);
        b.HasIndex(x => new { x.DocumentType, x.DocumentId });

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);
    }
}
