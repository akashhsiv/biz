using Erp.Domain.Audit;
using Erp.Domain.System;
using Erp.Domain.Whatsapp;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Erp.Infrastructure.Persistence.Configurations;

public class AuditLogConfiguration : IEntityTypeConfiguration<AuditLog>
{
    public void Configure(EntityTypeBuilder<AuditLog> b)
    {
        b.ToTable("audit_logs");
        b.HasKey(x => x.Id);
        b.Property(x => x.Action).HasMaxLength(100).IsRequired();
        b.Property(x => x.EntityType).HasMaxLength(100).IsRequired();
        b.Property(x => x.OldValueJson).HasColumnType("jsonb");
        b.Property(x => x.NewValueJson).HasColumnType("jsonb");

        b.HasIndex(x => new { x.EntityType, x.EntityId });
        b.HasIndex(x => new { x.UserId, x.CreatedAt });
        b.HasIndex(x => new { x.Action, x.CreatedAt });
    }
}

public class WhatsappOutboxItemConfiguration : IEntityTypeConfiguration<WhatsappOutboxItem>
{
    public void Configure(EntityTypeBuilder<WhatsappOutboxItem> b)
    {
        b.ToTable("whatsapp_outbox");
        b.HasKey(x => x.Id);
        b.Property(x => x.RecipientNumber).HasMaxLength(20).IsRequired();
        b.Property(x => x.PayloadJson).HasColumnType("jsonb").IsRequired();

        b.HasIndex(x => x.Status);
    }
}

public class IdempotencyKeyConfiguration : IEntityTypeConfiguration<Erp.Domain.System.IdempotencyKey>
{
    public void Configure(EntityTypeBuilder<Erp.Domain.System.IdempotencyKey> b)
    {
        b.ToTable("idempotency_keys");
        b.HasKey(x => x.Id);
        b.Property(x => x.Endpoint).HasMaxLength(200).IsRequired();
        b.Property(x => x.RequestHash).HasMaxLength(64).IsRequired();
        b.Property(x => x.ResponseBodyJson).HasColumnType("jsonb").IsRequired();
    }
}

public class DocumentSequenceConfiguration : IEntityTypeConfiguration<DocumentSequence>
{
    public void Configure(EntityTypeBuilder<DocumentSequence> b)
    {
        b.ToTable("document_sequences");
        b.HasKey(x => x.Id);
        b.Property(x => x.DocType).HasMaxLength(30).IsRequired();
        b.Property(x => x.FinancialYear).HasMaxLength(10).IsRequired();

        b.HasIndex(x => new { x.DocType, x.FinancialYear }).IsUnique();
    }
}

public class CompanySettingsConfiguration : IEntityTypeConfiguration<CompanySettings>
{
    public void Configure(EntityTypeBuilder<CompanySettings> b)
    {
        b.ToTable("company_settings");
        b.HasKey(x => x.Id);
        b.Property(x => x.ShopName).HasMaxLength(200).IsRequired();
        b.Property(x => x.Gstin).HasMaxLength(20).IsRequired();
        b.Property(x => x.State).HasMaxLength(50).IsRequired();
        b.Property(x => x.BankName).HasMaxLength(200);
        b.Property(x => x.BankAccountNumber).HasMaxLength(30);
        b.Property(x => x.BankIfscCode).HasMaxLength(15);
        b.Property(x => x.BankBranch).HasMaxLength(200);
        b.Property(x => x.QuotationTermsAndConditions).HasMaxLength(2000);
        b.Property(x => x.QuotationFooterNote).HasMaxLength(500);
        b.Property(x => x.ProformaTermsAndConditions).HasMaxLength(2000);
        b.Property(x => x.ProformaFooterNote).HasMaxLength(500);
        b.Property(x => x.SalesInvoiceTermsAndConditions).HasMaxLength(2000);
        b.Property(x => x.SalesInvoiceFooterNote).HasMaxLength(500);
        b.Property(x => x.PurchaseOrderTermsAndConditions).HasMaxLength(2000);
        b.Property(x => x.PurchaseOrderFooterNote).HasMaxLength(500);
    }
}

public class BackupHistoryConfiguration : IEntityTypeConfiguration<BackupHistory>
{
    public void Configure(EntityTypeBuilder<BackupHistory> b)
    {
        b.ToTable("backup_history");
        b.HasKey(x => x.Id);
        b.Property(x => x.FilePath).HasMaxLength(500).IsRequired();

        b.HasIndex(x => x.CreatedAt);
    }
}
