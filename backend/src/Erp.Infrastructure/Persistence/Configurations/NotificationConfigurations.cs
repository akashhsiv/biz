using Erp.Domain.Notifications;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class NotificationEventConfiguration : IEntityTypeConfiguration<NotificationEvent>
{
    public void Configure(EntityTypeBuilder<NotificationEvent> b)
    {
        b.ToTable("notification_events");
        b.HasKey(x => x.Id);
        b.Property(x => x.PayloadJson).IsRequired();
        b.Property(x => x.FailureReason).HasMaxLength(1000);

        b.HasIndex(x => new { x.Status, x.CreatedAt });
        b.HasIndex(x => new { x.ReferenceType, x.ReferenceId });

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class ShopNotificationSettingsConfiguration : IEntityTypeConfiguration<ShopNotificationSettings>
{
    public void Configure(EntityTypeBuilder<ShopNotificationSettings> b)
    {
        b.ToTable("shop_notification_settings");
        b.HasKey(x => x.Id);

        b.HasIndex(x => x.ShopId).IsUnique();

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class MobilePushOutboxItemConfiguration : IEntityTypeConfiguration<MobilePushOutboxItem>
{
    public void Configure(EntityTypeBuilder<MobilePushOutboxItem> b)
    {
        b.ToTable("mobile_push_outbox_items");
        b.HasKey(x => x.Id);
        b.Property(x => x.RecipientDescription).HasMaxLength(200).IsRequired();
        b.Property(x => x.PayloadJson).IsRequired();

        b.HasIndex(x => x.Status);

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.NotificationEvent).WithMany()
            .HasForeignKey(x => x.NotificationEventId).OnDelete(DeleteBehavior.Restrict);
    }
}
