using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Domain.Customers;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record CustomerDto(
    Guid Id, string CustomerCode, string Name, CustomerType CustomerType, string? GstNumber, string? GstState,
    string? ContactNumber, string? Email, string? BillingAddress, string? ShippingAddress, bool IsActive);

public record UpsertCustomerRequest(
    string Name, CustomerType CustomerType, string? GstNumber, string? GstState,
    string? ContactNumber, string? Email, string? BillingAddress, string? ShippingAddress);

[ApiController]
[Route("api/customers")]
public class CustomersController(ErpDbContext db, IAuditService audit, IDocumentNumberService documentNumbers) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.CustomersView)]
    public async Task<ActionResult<List<CustomerDto>>> List([FromQuery] bool includeInactive, CancellationToken ct)
    {
        var query = db.Customers.AsQueryable();
        if (!includeInactive) query = query.Where(c => c.IsActive);

        var customers = await query.OrderBy(c => c.Name).Select(c => ToDto(c)).ToListAsync(ct);
        return Ok(customers);
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.CustomersView)]
    public async Task<ActionResult<CustomerDto>> Get(Guid id, CancellationToken ct)
    {
        var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Customer), id);

        return Ok(ToDto(customer));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.CustomersManage)]
    public async Task<ActionResult<CustomerDto>> Create(UpsertCustomerRequest request, CancellationToken ct)
    {
        Validate(request);

        var customer = new Customer
        {
            CustomerCode = await documentNumbers.NextGlobalNumberAsync("customer", "CUST", ct),
            Name = request.Name,
            CustomerType = request.CustomerType,
            GstNumber = request.CustomerType == CustomerType.Registered ? request.GstNumber : null,
            GstState = request.CustomerType == CustomerType.Registered ? request.GstState : null,
            ContactNumber = request.ContactNumber,
            Email = request.Email,
            BillingAddress = request.BillingAddress,
            ShippingAddress = request.ShippingAddress,
            IsActive = true,
        };

        db.Customers.Add(customer);
        await audit.LogAsync("customer.created", nameof(Customer), customer.Id, newValue: request, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(customer));
    }

    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.CustomersManage)]
    public async Task<ActionResult<CustomerDto>> Update(Guid id, UpsertCustomerRequest request, CancellationToken ct)
    {
        Validate(request);

        var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Customer), id);

        var oldValue = ToDto(customer);
        var gstChanged = customer.GstNumber != request.GstNumber || customer.GstState != request.GstState;

        customer.Name = request.Name;
        customer.CustomerType = request.CustomerType;
        customer.GstNumber = request.CustomerType == CustomerType.Registered ? request.GstNumber : null;
        customer.GstState = request.CustomerType == CustomerType.Registered ? request.GstState : null;
        customer.ContactNumber = request.ContactNumber;
        customer.Email = request.Email;
        customer.BillingAddress = request.BillingAddress;
        customer.ShippingAddress = request.ShippingAddress;

        await audit.LogAsync(gstChanged ? "customer.gst_updated" : "customer.updated", nameof(Customer), customer.Id, oldValue, ToDto(customer), ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(customer));
    }

    [HttpPost("{id:guid}/deactivate")]
    [RequirePermission(PermissionKeys.CustomersManage)]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken ct)
    {
        var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Customer), id);

        customer.IsActive = false;
        await audit.LogAsync("customer.deactivated", nameof(Customer), customer.Id, ct: ct);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }

    private static void Validate(UpsertCustomerRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationAppException("Customer name is required.");

        if (request.CustomerType == CustomerType.Registered && string.IsNullOrWhiteSpace(request.GstNumber))
            throw new ValidationAppException("GST number is required for a GST-registered customer.");
    }

    private static CustomerDto ToDto(Customer c) => new(
        c.Id, c.CustomerCode, c.Name, c.CustomerType, c.GstNumber, c.GstState,
        c.ContactNumber, c.Email, c.BillingAddress, c.ShippingAddress, c.IsActive);
}
