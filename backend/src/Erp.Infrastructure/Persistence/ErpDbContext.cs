using Erp.Application.Common;
using Erp.Domain.Audit;
using Erp.Domain.Common;
using Erp.Domain.Customers;
using Erp.Domain.Finance;
using Erp.Domain.Identity;
using Erp.Domain.Items;
using Erp.Domain.Purchases;
using Erp.Domain.Sales;
using Erp.Domain.System;
using Erp.Domain.Whatsapp;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Persistence;

public class ErpDbContext(DbContextOptions<ErpDbContext> options, ICurrentUserService? currentUser = null) : DbContext(options)
{

    // Identity
    public DbSet<User> Users => Set<User>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Permission> Permissions => Set<Permission>();
    public DbSet<RolePermission> RolePermissions => Set<RolePermission>();
    public DbSet<Session> Sessions => Set<Session>();

    // Customers
    public DbSet<Customer> Customers => Set<Customer>();

    // Items & Stock
    public DbSet<ItemCategory> ItemCategories => Set<ItemCategory>();
    public DbSet<TaxGroup> TaxGroups => Set<TaxGroup>();
    public DbSet<Item> Items => Set<Item>();
    public DbSet<ItemBatch> ItemBatches => Set<ItemBatch>();
    public DbSet<ItemSerial> ItemSerials => Set<ItemSerial>();
    public DbSet<StockBalance> StockBalances => Set<StockBalance>();
    public DbSet<StockMovement> StockMovements => Set<StockMovement>();

    // Finance ledger
    public DbSet<FinancialTransaction> FinancialTransactions => Set<FinancialTransaction>();
    public DbSet<CustomerDeposit> CustomerDeposits => Set<CustomerDeposit>();
    public DbSet<DepositAllocation> DepositAllocations => Set<DepositAllocation>();
    public DbSet<Expense> Expenses => Set<Expense>();

    // Sales chain
    public DbSet<Quotation> Quotations => Set<Quotation>();
    public DbSet<QuotationLine> QuotationLines => Set<QuotationLine>();
    public DbSet<ProformaInvoice> ProformaInvoices => Set<ProformaInvoice>();
    public DbSet<ProformaLine> ProformaLines => Set<ProformaLine>();
    public DbSet<SalesInvoice> SalesInvoices => Set<SalesInvoice>();
    public DbSet<SalesInvoiceLine> SalesInvoiceLines => Set<SalesInvoiceLine>();
    public DbSet<ReturnPolicy> ReturnPolicies => Set<ReturnPolicy>();
    public DbSet<SalesReturn> SalesReturns => Set<SalesReturn>();
    public DbSet<SalesReturnLine> SalesReturnLines => Set<SalesReturnLine>();

    // Purchase chain
    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<PurchaseOrder> PurchaseOrders => Set<PurchaseOrder>();
    public DbSet<PurchaseOrderLine> PurchaseOrderLines => Set<PurchaseOrderLine>();
    public DbSet<PurchaseReceipt> PurchaseReceipts => Set<PurchaseReceipt>();
    public DbSet<PurchaseReceiptLine> PurchaseReceiptLines => Set<PurchaseReceiptLine>();
    public DbSet<PurchasePayment> PurchasePayments => Set<PurchasePayment>();

    // Audit / WhatsApp / System
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<WhatsappOutboxItem> WhatsappOutboxItems => Set<WhatsappOutboxItem>();
    public DbSet<Erp.Domain.System.IdempotencyKey> IdempotencyKeys => Set<Erp.Domain.System.IdempotencyKey>();
    public DbSet<DocumentSequence> DocumentSequences => Set<DocumentSequence>();
    public DbSet<CompanySettings> CompanySettings => Set<CompanySettings>();
    public DbSet<BackupHistory> BackupHistories => Set<BackupHistory>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // DocumentLineBase is a shared C# shape, not a mapped hierarchy — each of
        // QuotationLine/ProformaLine/SalesInvoiceLine gets its own physical table.
        modelBuilder.Ignore<Erp.Domain.Sales.DocumentLineBase>();

        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ErpDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        StampAuditColumns();
        return base.SaveChangesAsync(cancellationToken);
    }

    public override int SaveChanges()
    {
        StampAuditColumns();
        return base.SaveChanges();
    }

    /// <summary>Server-stamped, never client-supplied — matches the confirmed rule that timestamps come from the Host, not a Slave's clock.</summary>
    private void StampAuditColumns()
    {
        var userId = currentUser?.UserId ?? Guid.Empty;
        var now = DateTime.UtcNow;

        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CreatedBy = userId;
                entry.Entity.CreatedAt = now;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedBy = userId;
                entry.Entity.UpdatedAt = now;
            }
        }
    }
}
