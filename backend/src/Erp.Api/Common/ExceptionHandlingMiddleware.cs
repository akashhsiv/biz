using Erp.Application.Common;
using Erp.Infrastructure.Common;
using Microsoft.AspNetCore.Mvc;

namespace Erp.Api.Common;

public class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            var (status, title) = ex switch
            {
                NotFoundAppException => (StatusCodes.Status404NotFound, "Not Found"),
                ValidationAppException => (StatusCodes.Status400BadRequest, "Validation Failed"),
                ConflictAppException => (StatusCodes.Status409Conflict, "Conflict"),
                ForbiddenAppException => (StatusCodes.Status403Forbidden, "Forbidden"),
                _ => (StatusCodes.Status500InternalServerError, "Unexpected Error"),
            };

            if (status == StatusCodes.Status500InternalServerError)
            {
                logger.LogError(ex, "Unhandled exception on {Method} {Path}", context.Request.Method, context.Request.Path);
                await ServerFileLogger.LogAsync("http", $"{context.Request.Method} {context.Request.Path}{context.Request.QueryString}\n{ex}");
            }

            var problem = new ProblemDetails
            {
                Status = status,
                Title = title,
                Detail = status == StatusCodes.Status500InternalServerError ? "An unexpected error occurred." : ex.Message,
            };

            context.Response.StatusCode = status;
            context.Response.ContentType = "application/problem+json";
            await context.Response.WriteAsJsonAsync(problem);
        }
    }
}
