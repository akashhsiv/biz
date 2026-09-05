using Erp.Domain.Customers;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class CustomerConfiguration : IEntityTypeConfiguration<Customer>
{
    public void Configure(EntityTypeBuilder<Customer> b)
    {
        b.ToTable("customers");
        b.HasKey(x => x.Id);
        b.Property(x => x.CustomerCode).HasMaxLength(30).IsRequired();
        b.Property(x => x.Name).HasMaxLength(200).IsRequired();
        b.Property(x => x.GstNumber).HasMaxLength(20);
        b.Property(x => x.CreditLimit).HasPrecision(18, 2);

        b.HasIndex(x => new { x.ShopId, x.CustomerCode }).IsUnique();
        b.HasIndex(x => x.GstNumber);
        b.HasIndex(x => x.Name);

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);
    }
}
