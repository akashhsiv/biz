using Erp.Application.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Services;

public class DocumentNumberService(ErpDbContext db, ICurrentUserService currentUser) : IDocumentNumberService
{
    public string CurrentFinancialYear()
    {
        var now = DateTime.UtcNow;
        // Indian financial year runs Apr(1)-Mar(31). Jan-Mar belongs to the year that started the previous April.
        var startYear = now.Month >= 4 ? now.Year : now.Year - 1;
        return $"{startYear}-{(startYear + 1) % 100:D2}";
    }

    /// <summary>Sequences are per-shop (multi-shop rework) — the unique constraint is now
    /// (ShopId, DocType, FinancialYear), so the ON CONFLICT target below must name all three.</summary>
    public async Task<string> NextNumberAsync(string docType, string prefix, CancellationToken ct = default)
    {
        var financialYear = CurrentFinancialYear();
        var shopId = RequireShopId();

        var results = await db.Database.SqlQuery<long>($"""
            INSERT INTO document_sequences ("Id", "ShopId", "DocType", "FinancialYear", "LastNumber")
            VALUES ({Guid.NewGuid()}, {shopId}, {docType}, {financialYear}, 1)
            ON CONFLICT ("ShopId", "DocType", "FinancialYear")
            DO UPDATE SET "LastNumber" = document_sequences."LastNumber" + 1
            RETURNING "LastNumber"
            """).ToListAsync(ct);

        return $"{prefix}-{financialYear}-{results.Single():D4}";
    }

    public async Task<string> NextGlobalNumberAsync(string docType, string prefix, CancellationToken ct = default)
    {
        const string globalBucket = "ALL";
        var shopId = RequireShopId();

        var results = await db.Database.SqlQuery<long>($"""
            INSERT INTO document_sequences ("Id", "ShopId", "DocType", "FinancialYear", "LastNumber")
            VALUES ({Guid.NewGuid()}, {shopId}, {docType}, {globalBucket}, 1)
            ON CONFLICT ("ShopId", "DocType", "FinancialYear")
            DO UPDATE SET "LastNumber" = document_sequences."LastNumber" + 1
            RETURNING "LastNumber"
            """).ToListAsync(ct);

        return $"{prefix}-{results.Single():D4}";
    }

    private Guid RequireShopId() => currentUser.CurrentShopId
        ?? throw new ConflictAppException("No shop selected for this session — call POST /api/auth/select-shop first.");
}
