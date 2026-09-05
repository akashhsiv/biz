using System.Linq.Expressions;
using System.Reflection;
using Erp.Application.Common;
using Erp.Domain.Audit;
using Erp.Domain.Common;
using Erp.Domain.Customers;
using Erp.Domain.Finance;
using Erp.Domain.Identity;
using Erp.Domain.Items;
using Erp.Domain.Purchases;
using Erp.Domain.Sales;
using Erp.Domain.Shops;
using Erp.Domain.Staff;
using Erp.Domain.System;
using Erp.Domain.Whatsapp;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Persistence;

public class ErpDbContext(DbContextOptions<ErpDbContext> options, ICurrentUserService? currentUser = null) : DbContext(options)
{

    // Shops
    public DbSet<Company> Companies => Set<Company>();
    public DbSet<Shop> Shops => Set<Shop>();

    // Identity
    public DbSet<User> Users => Set<User>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Permission> Permissions => Set<Permission>();
    public DbSet<RolePermission> RolePermissions => Set<RolePermission>();
    public DbSet<Session> Sessions => Set<Session>();
    public DbSet<UserShopRole> UserShopRoles => Set<UserShopRole>();

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

    // Staff & Salary
    public DbSet<Erp.Domain.Staff.Staff> Staff => Set<Erp.Domain.Staff.Staff>();
    public DbSet<SalaryPayment> SalaryPayments => Set<SalaryPayment>();
    public DbSet<SalaryPaymentEntry> SalaryPaymentEntries => Set<SalaryPaymentEntry>();

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

        ApplyShopQueryFilters(modelBuilder);

        base.OnModelCreating(modelBuilder);
    }

    /// <summary>Multi-shop rework: every entity implementing IShopScoped gets a global query filter
    /// restricting reads to the caller's active shop, resolved from ICurrentUserService (injected the
    /// same way the audit-stamping code above resolves the current user) rather than trusted from a
    /// client-supplied ShopId. When no shop is selected yet (CurrentShopId is null — e.g. a session
    /// that hasn't called select-shop, a background job, or design-time tooling with no HTTP context)
    /// the filter is a no-op rather than hiding every row; that's a deliberate transitional choice so
    /// existing single-shop deployments and pre-shop-selection requests don't break outright.</summary>
    private void ApplyShopQueryFilters(ModelBuilder modelBuilder)
    {
        var applyMethod = typeof(ErpDbContext).GetMethod(nameof(ApplyShopQueryFilter), BindingFlags.NonPublic | BindingFlags.Instance)!;

        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            if (!typeof(IShopScoped).IsAssignableFrom(entityType.ClrType)) continue;
            if (entityType.BaseType is not null) continue; // filters apply to the root of a hierarchy only; none of these are hierarchies today

            applyMethod.MakeGenericMethod(entityType.ClrType).Invoke(this, new object[] { modelBuilder });
        }
    }

    private void ApplyShopQueryFilter<TEntity>(ModelBuilder modelBuilder) where TEntity : class, IShopScoped
    {
        modelBuilder.Entity<TEntity>().HasQueryFilter(e => !CurrentShopIdForFilter.HasValue || e.ShopId == CurrentShopIdForFilter);
    }

    /// <summary>Backing member for the query filter lambdas above — EF captures this as a per-instance
    /// parameter (the same mechanism the audit-stamping code uses `currentUser` for), so each request's
    /// DbContext instance filters against its own resolved shop.</summary>
    private Guid? CurrentShopIdForFilter => currentUser?.CurrentShopId;

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

        StampShopId();
    }

    /// <summary>Same mechanism/style as StampAuditColumns above: for every newly-added IShopScoped
    /// entity that hasn't already had ShopId explicitly set by the caller (e.g. seed/backfill code,
    /// or an admin flow creating data across shops), stamp it from ICurrentUserService.CurrentShopId.
    /// A shop-scoped entity being created with no shop selected is a genuine bug — the request should
    /// have required shop selection before reaching this point — so we throw rather than silently
    /// writing Guid.Empty (which would violate the FK to Shops or bypass the query filter).</summary>
    private void StampShopId()
    {
        foreach (var entry in ChangeTracker.Entries<IShopScoped>())
        {
            if (entry.State != EntityState.Added) continue;
            if (entry.Entity.ShopId != Guid.Empty) continue; // caller already set it explicitly — don't override

            var shopId = currentUser?.CurrentShopId
                ?? throw new InvalidOperationException(
                    $"Cannot create a {entry.Entity.GetType().Name} without a ShopId: no shop is selected for the current request (ICurrentUserService.CurrentShopId is null). " +
                    "Either select a shop before performing this operation, or set ShopId explicitly when constructing the entity.");

            entry.Entity.ShopId = shopId;
        }
    }
}
