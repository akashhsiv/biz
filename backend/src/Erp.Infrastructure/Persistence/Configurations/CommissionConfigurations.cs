using Erp.Domain.Commission;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class CustomerProductRateConfiguration : IEntityTypeConfiguration<CustomerProductRate>
{
    public void Configure(EntityTypeBuilder<CustomerProductRate> b)
    {
        b.ToTable("customer_product_rates");
        b.HasKey(x => x.Id);

        b.Property(x => x.SpecialRate).HasPrecision(18, 2);
        b.Property(x => x.CommissionRate).HasPrecision(9, 4);

        b.HasIndex(x => new { x.ShopId, x.CustomerId, x.ItemId });

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Item).WithMany()
            .HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class CommissionEntryConfiguration : IEntityTypeConfiguration<CommissionEntry>
{
    public void Configure(EntityTypeBuilder<CommissionEntry> b)
    {
        b.ToTable("commission_entries");
        b.HasKey(x => x.Id);

        b.Property(x => x.Amount).HasPrecision(18, 2);
        b.Property(x => x.PaidAmount).HasPrecision(18, 2);

        b.HasIndex(x => new { x.ShopId, x.CustomerId, x.Status });
        b.HasIndex(x => x.SalesInvoiceId);

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.SalesInvoice).WithMany()
            .HasForeignKey(x => x.SalesInvoiceId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Item).WithMany()
            .HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
    }
}
