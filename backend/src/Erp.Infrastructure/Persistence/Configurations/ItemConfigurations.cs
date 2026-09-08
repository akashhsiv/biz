using Erp.Domain.Items;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class ItemCategoryConfiguration : IEntityTypeConfiguration<ItemCategory>
{
    public void Configure(EntityTypeBuilder<ItemCategory> b)
    {
        b.ToTable("item_categories");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(100).IsRequired();

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class TaxGroupConfiguration : IEntityTypeConfiguration<TaxGroup>
{
    public void Configure(EntityTypeBuilder<TaxGroup> b)
    {
        b.ToTable("tax_groups");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(50).IsRequired();
        b.Property(x => x.RatePercent).HasPrecision(5, 2);
    }
}

public class ItemConfiguration : IEntityTypeConfiguration<Item>
{
    public void Configure(EntityTypeBuilder<Item> b)
    {
        b.ToTable("items");
        b.HasKey(x => x.Id);
        b.Property(x => x.Sku).HasMaxLength(50).IsRequired();
        b.Property(x => x.Name).HasMaxLength(200).IsRequired();
        b.Property(x => x.Unit).HasMaxLength(20).IsRequired();
        b.Property(x => x.PurchasePrice).HasPrecision(18, 2);
        b.Property(x => x.SellingPrice).HasPrecision(18, 2);
        b.Property(x => x.TaxRatePercent).HasPrecision(5, 2);
        b.Property(x => x.HsnCode).HasMaxLength(20);
        b.Property(x => x.MinimumStock).HasPrecision(18, 3);

        b.HasIndex(x => new { x.ShopId, x.Sku }).IsUnique();
        b.HasIndex(x => x.Name);

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Category).WithMany()
            .HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Brand).WithMany()
            .HasForeignKey(x => x.BrandId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.StockBalance).WithOne(x => x.Item)
            .HasForeignKey<StockBalance>(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class BrandConfiguration : IEntityTypeConfiguration<Brand>
{
    public void Configure(EntityTypeBuilder<Brand> b)
    {
        b.ToTable("brands");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(200).IsRequired();

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Category).WithMany()
            .HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class ItemBatchConfiguration : IEntityTypeConfiguration<ItemBatch>
{
    public void Configure(EntityTypeBuilder<ItemBatch> b)
    {
        b.ToTable("item_batches");
        b.HasKey(x => x.Id);
        b.Property(x => x.BatchNumber).HasMaxLength(50).IsRequired();
        b.Property(x => x.QuantityOnHand).HasPrecision(18, 3);

        b.HasIndex(x => new { x.ItemId, x.BatchNumber }).IsUnique();

        b.HasOne(x => x.Item).WithMany(x => x.Batches)
            .HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class ItemSerialConfiguration : IEntityTypeConfiguration<ItemSerial>
{
    public void Configure(EntityTypeBuilder<ItemSerial> b)
    {
        b.ToTable("item_serials");
        b.HasKey(x => x.Id);
        b.Property(x => x.SerialNumber).HasMaxLength(100).IsRequired();

        b.HasIndex(x => new { x.ItemId, x.SerialNumber }).IsUnique();

        b.HasOne(x => x.Item).WithMany(x => x.Serials)
            .HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class StockBalanceConfiguration : IEntityTypeConfiguration<StockBalance>
{
    public void Configure(EntityTypeBuilder<StockBalance> b)
    {
        b.ToTable("stock_balances");
        b.HasKey(x => x.ItemId);
        b.Property(x => x.QuantityOnHand).HasPrecision(18, 3);
        b.Property(x => x.Version).IsRowVersion();
    }
}

public class StockMovementConfiguration : IEntityTypeConfiguration<StockMovement>
{
    public void Configure(EntityTypeBuilder<StockMovement> b)
    {
        b.ToTable("stock_movements");
        b.HasKey(x => x.Id);
        b.Property(x => x.QuantityDelta).HasPrecision(18, 3);
        b.Property(x => x.QuantityBefore).HasPrecision(18, 3);
        b.Property(x => x.QuantityAfter).HasPrecision(18, 3);

        b.HasIndex(x => new { x.ItemId, x.CreatedAt });
        b.HasIndex(x => new { x.ReferenceType, x.ReferenceId });

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Item).WithMany()
            .HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Batch).WithMany()
            .HasForeignKey(x => x.BatchId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Serial).WithMany()
            .HasForeignKey(x => x.SerialId).OnDelete(DeleteBehavior.Restrict);
    }
}
