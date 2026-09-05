using Erp.Domain.Purchases;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class SupplierConfiguration : IEntityTypeConfiguration<Supplier>
{
    public void Configure(EntityTypeBuilder<Supplier> b)
    {
        b.ToTable("suppliers");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(200).IsRequired();
        b.Property(x => x.GstNumber).HasMaxLength(20);
        b.Property(x => x.State).HasMaxLength(50);
    }
}

public class PurchaseOrderConfiguration : IEntityTypeConfiguration<PurchaseOrder>
{
    public void Configure(EntityTypeBuilder<PurchaseOrder> b)
    {
        b.ToTable("purchase_orders");
        b.HasKey(x => x.Id);
        b.Property(x => x.PoNumber).HasMaxLength(30).IsRequired();
        b.Property(x => x.FinancialYear).HasMaxLength(10).IsRequired();
        b.Property(x => x.Subtotal).HasPrecision(18, 2);
        b.Property(x => x.TaxTotal).HasPrecision(18, 2);
        b.Property(x => x.GrandTotal).HasPrecision(18, 2);

        b.HasIndex(x => x.PoNumber).IsUnique();

        b.HasOne(x => x.Supplier).WithMany()
            .HasForeignKey(x => x.SupplierId).OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Lines).WithOne(x => x.PurchaseOrder)
            .HasForeignKey(x => x.PurchaseOrderId).OnDelete(DeleteBehavior.Cascade);

        b.HasMany(x => x.Receipts).WithOne(x => x.PurchaseOrder)
            .HasForeignKey(x => x.PurchaseOrderId).OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Payments).WithOne(x => x.PurchaseOrder)
            .HasForeignKey(x => x.PurchaseOrderId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class PurchaseOrderLineConfiguration : IEntityTypeConfiguration<PurchaseOrderLine>
{
    public void Configure(EntityTypeBuilder<PurchaseOrderLine> b)
    {
        b.ToTable("purchase_order_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.QuantityOrdered).HasPrecision(18, 3);
        b.Property(x => x.QuantityReceived).HasPrecision(18, 3);
        b.Property(x => x.Rate).HasPrecision(18, 2);
        b.Property(x => x.TaxRatePercent).HasPrecision(5, 2);
        b.Property(x => x.CgstAmount).HasPrecision(18, 2);
        b.Property(x => x.SgstAmount).HasPrecision(18, 2);
        b.Property(x => x.IgstAmount).HasPrecision(18, 2);
        b.Property(x => x.LineTotal).HasPrecision(18, 2);

        b.HasOne(x => x.Item).WithMany()
            .HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class PurchaseReceiptConfiguration : IEntityTypeConfiguration<PurchaseReceipt>
{
    public void Configure(EntityTypeBuilder<PurchaseReceipt> b)
    {
        b.ToTable("purchase_receipts");
        b.HasKey(x => x.Id);
        b.Property(x => x.ReceiptNumber).HasMaxLength(30).IsRequired();
        b.Property(x => x.FinancialYear).HasMaxLength(10).IsRequired();

        b.HasIndex(x => x.ReceiptNumber).IsUnique();

        b.HasMany(x => x.Lines).WithOne(x => x.PurchaseReceipt)
            .HasForeignKey(x => x.PurchaseReceiptId).OnDelete(DeleteBehavior.Cascade);
    }
}

public class PurchaseReceiptLineConfiguration : IEntityTypeConfiguration<PurchaseReceiptLine>
{
    public void Configure(EntityTypeBuilder<PurchaseReceiptLine> b)
    {
        b.ToTable("purchase_receipt_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.QuantityReceived).HasPrecision(18, 3);

        b.HasOne(x => x.PoLine).WithMany()
            .HasForeignKey(x => x.PoLineId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class PurchasePaymentConfiguration : IEntityTypeConfiguration<PurchasePayment>
{
    public void Configure(EntityTypeBuilder<PurchasePayment> b)
    {
        b.ToTable("purchase_payments");
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasPrecision(18, 2);
    }
}
