using Microsoft.AspNetCore.Authorization;

namespace Erp.Api.Auth;

/// <summary>Requires the caller's session to carry User.IsSuperAdmin — for api/admin endpoints that
/// provision shops and Shop Admins, above the shop-scoped permission system entirely. Mirrors
/// RequirePermissionAttribute's shape but references the single "SuperAdmin" policy registered in
/// Program.cs rather than one policy per permission key.</summary>
public class RequireSuperAdminAttribute() : AuthorizeAttribute(policy: SessionAuthDefaults.SuperAdminPolicy);
