using Erp.Domain.Notifications;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class DeviceTokenConfiguration : IEntityTypeConfiguration<DeviceToken>
{
    public void Configure(EntityTypeBuilder<DeviceToken> b)
    {
        b.ToTable("device_tokens");
        b.HasKey(x => x.Id);
        b.Property(x => x.Token).HasMaxLength(500).IsRequired();
        b.Property(x => x.Platform).HasMaxLength(30).IsRequired();

        b.HasIndex(x => x.Token).IsUnique();
        b.HasIndex(x => x.UserId);

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);
    }
}
