using Erp.Domain.Sales;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

file static class LineDefaults
{
    public static void ConfigureLine<TLine>(EntityTypeBuilder<TLine> b) where TLine : DocumentLineBase
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Description).HasMaxLength(300).IsRequired();
        b.Property(x => x.Quantity).HasPrecision(18, 3);
        b.Property(x => x.Rate).HasPrecision(18, 2);
        b.Property(x => x.Discount).HasPrecision(18, 2);
        b.Property(x => x.TaxRatePercent).HasPrecision(5, 2);
        b.Property(x => x.CgstAmount).HasPrecision(18, 2);
        b.Property(x => x.SgstAmount).HasPrecision(18, 2);
        b.Property(x => x.IgstAmount).HasPrecision(18, 2);
        b.Property(x => x.LineTotal).HasPrecision(18, 2);

        b.HasOne(x => x.Item).WithMany()
            .HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class QuotationConfiguration : IEntityTypeConfiguration<Quotation>
{
    public void Configure(EntityTypeBuilder<Quotation> b)
    {
        b.ToTable("quotations");
        b.HasKey(x => x.Id);
        b.Property(x => x.QuotationNumber).HasMaxLength(30).IsRequired();
        b.Property(x => x.FinancialYear).HasMaxLength(10).IsRequired();
        DecimalCols(b);

        b.HasIndex(x => new { x.ShopId, x.QuotationNumber }).IsUnique();
        b.HasIndex(x => new { x.CustomerId, x.CreatedAt });

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Lines).WithOne(x => x.Quotation)
            .HasForeignKey(x => x.QuotationId).OnDelete(DeleteBehavior.Cascade);
    }

    private static void DecimalCols(EntityTypeBuilder<Quotation> b)
    {
        b.Property(x => x.Subtotal).HasPrecision(18, 2);
        b.Property(x => x.OverallDiscountValue).HasPrecision(18, 2);
        b.Property(x => x.OverallDiscountAmount).HasPrecision(18, 2);
        b.Property(x => x.TaxTotal).HasPrecision(18, 2);
        b.Property(x => x.GrandTotal).HasPrecision(18, 2);
    }
}

public class QuotationLineConfiguration : IEntityTypeConfiguration<QuotationLine>
{
    public void Configure(EntityTypeBuilder<QuotationLine> b)
    {
        b.ToTable("quotation_lines");
        LineDefaults.ConfigureLine(b);
    }
}

public class ProformaInvoiceConfiguration : IEntityTypeConfiguration<ProformaInvoice>
{
    public void Configure(EntityTypeBuilder<ProformaInvoice> b)
    {
        b.ToTable("proforma_invoices");
        b.HasKey(x => x.Id);
        b.Property(x => x.ProformaNumber).HasMaxLength(30).IsRequired();
        b.Property(x => x.FinancialYear).HasMaxLength(10).IsRequired();
        DecimalCols(b);

        b.HasIndex(x => new { x.ShopId, x.ProformaNumber }).IsUnique();
        b.HasIndex(x => x.CustomerId);

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Quotation).WithMany()
            .HasForeignKey(x => x.QuotationId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Lines).WithOne(x => x.Proforma)
            .HasForeignKey(x => x.ProformaId).OnDelete(DeleteBehavior.Cascade);
    }

    private static void DecimalCols(EntityTypeBuilder<ProformaInvoice> b)
    {
        b.Property(x => x.Subtotal).HasPrecision(18, 2);
        b.Property(x => x.OverallDiscountValue).HasPrecision(18, 2);
        b.Property(x => x.OverallDiscountAmount).HasPrecision(18, 2);
        b.Property(x => x.TaxTotal).HasPrecision(18, 2);
        b.Property(x => x.GrandTotal).HasPrecision(18, 2);
        b.Property(x => x.AllocatedTotal).HasPrecision(18, 2);
        b.Property(x => x.OutstandingTotal).HasPrecision(18, 2);
    }
}

public class ProformaLineConfiguration : IEntityTypeConfiguration<ProformaLine>
{
    public void Configure(EntityTypeBuilder<ProformaLine> b)
    {
        b.ToTable("proforma_lines");
        LineDefaults.ConfigureLine(b);
    }
}

public class SalesInvoiceConfiguration : IEntityTypeConfiguration<SalesInvoice>
{
    public void Configure(EntityTypeBuilder<SalesInvoice> b)
    {
        b.ToTable("sales_invoices");
        b.HasKey(x => x.Id);
        b.Property(x => x.InvoiceNumber).HasMaxLength(30).IsRequired();
        b.Property(x => x.FinancialYear).HasMaxLength(10).IsRequired();
        DecimalCols(b);

        b.HasIndex(x => new { x.ShopId, x.InvoiceNumber }).IsUnique();
        b.HasIndex(x => new { x.CustomerId, x.CreatedAt });

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Lines).WithOne(x => x.SalesInvoice)
            .HasForeignKey(x => x.SalesInvoiceId).OnDelete(DeleteBehavior.Cascade);
    }

    private static void DecimalCols(EntityTypeBuilder<SalesInvoice> b)
    {
        b.Property(x => x.Subtotal).HasPrecision(18, 2);
        b.Property(x => x.OverallDiscountValue).HasPrecision(18, 2);
        b.Property(x => x.OverallDiscountAmount).HasPrecision(18, 2);
        b.Property(x => x.TaxTotal).HasPrecision(18, 2);
        b.Property(x => x.GrandTotal).HasPrecision(18, 2);
        b.Property(x => x.DepositAllocatedTotal).HasPrecision(18, 2);
    }
}

public class SalesInvoiceLineConfiguration : IEntityTypeConfiguration<SalesInvoiceLine>
{
    public void Configure(EntityTypeBuilder<SalesInvoiceLine> b)
    {
        b.ToTable("sales_invoice_lines");
        LineDefaults.ConfigureLine(b);
    }
}

public class ReturnPolicyConfiguration : IEntityTypeConfiguration<ReturnPolicy>
{
    public void Configure(EntityTypeBuilder<ReturnPolicy> b)
    {
        b.ToTable("return_policies");
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).HasMaxLength(100).IsRequired();
        b.Property(x => x.RestockingFeePercent).HasPrecision(5, 2);

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Category).WithMany()
            .HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
    }
}

public class SalesReturnConfiguration : IEntityTypeConfiguration<SalesReturn>
{
    public void Configure(EntityTypeBuilder<SalesReturn> b)
    {
        b.ToTable("sales_returns");
        b.HasKey(x => x.Id);
        b.Property(x => x.ReturnNumber).HasMaxLength(30).IsRequired();
        b.Property(x => x.FinancialYear).HasMaxLength(10).IsRequired();
        b.Property(x => x.TotalRefundAmount).HasPrecision(18, 2);

        b.HasIndex(x => new { x.ShopId, x.ReturnNumber }).IsUnique();

        b.HasOne(x => x.Shop).WithMany()
            .HasForeignKey(x => x.ShopId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.SalesInvoice).WithMany()
            .HasForeignKey(x => x.SalesInvoiceId).OnDelete(DeleteBehavior.Restrict);

        b.HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Lines).WithOne(x => x.SalesReturn)
            .HasForeignKey(x => x.SalesReturnId).OnDelete(DeleteBehavior.Cascade);
    }
}

public class SalesReturnLineConfiguration : IEntityTypeConfiguration<SalesReturnLine>
{
    public void Configure(EntityTypeBuilder<SalesReturnLine> b)
    {
        b.ToTable("sales_return_lines");
        b.HasKey(x => x.Id);
        b.Property(x => x.QuantityReturned).HasPrecision(18, 3);
        b.Property(x => x.RefundAmount).HasPrecision(18, 2);

        b.HasOne(x => x.SalesInvoiceLine).WithMany()
            .HasForeignKey(x => x.SalesInvoiceLineId).OnDelete(DeleteBehavior.Restrict);
    }
}
