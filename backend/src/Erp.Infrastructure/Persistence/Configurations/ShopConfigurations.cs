using Erp.Domain.Identity;
using Erp.Domain.Shops;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class CompanyConfiguration : IEntityTypeConfiguration<Company>
{
    public void Configure(EntityTypeBuilder<Company> b)
    {
        b.ToTable("companies");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(200).IsRequired();
    }
}

public class ShopConfiguration : IEntityTypeConfiguration<Shop>
{
    public void Configure(EntityTypeBuilder<Shop> b)
    {
        b.ToTable("shops");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(200).IsRequired();
        b.Property(x => x.Gstin).HasMaxLength(20).IsRequired();
        b.Property(x => x.Address).HasMaxLength(500);
        b.Property(x => x.ContactNumber).HasMaxLength(20);

        b.HasIndex(x => x.Gstin);

        b.HasOne(x => x.Company).WithMany(x => x.Shops)
            .HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class UserShopRoleConfiguration : IEntityTypeConfiguration<UserShopRole>
{
    public void Configure(EntityTypeBuilder<UserShopRole> b)
    {
        b.ToTable("user_shop_roles");
        b.HasKey(x => x.Id);

        // One role per user per shop.
        b.HasIndex(x => new { x.UserId, x.ShopId }).IsUnique();

        b.HasOne(x => x.User).WithMany(x => x.UserShopRoles)
            .HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);

        b.HasOne(x => x.Shop).WithMany(x => x.UserShopRoles)
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Cascade);

        b.HasOne(x => x.Role).WithMany()
            .HasForeignKey(x => x.RoleId).OnDelete(DeleteBehavior.Restrict);
    }
}
