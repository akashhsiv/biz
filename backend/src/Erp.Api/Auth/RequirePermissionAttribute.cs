using Microsoft.AspNetCore.Authorization;

namespace Erp.Api.Auth;

/// <summary>Requires the caller's session to carry the given permission claim. One ASP.NET Core authorization policy is registered per PermissionKeys entry at startup (see Program.cs).</summary>
public class RequirePermissionAttribute(string permissionKey) : AuthorizeAttribute(policy: permissionKey);
