using System.Security.Claims;
using FreeTongRide.Application.Common;
using FreeTongRide.Domain.Enums;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Api.Infrastructure;

public static class ClaimsExtensions
{
    public static Guid UserId(this ClaimsPrincipal user) =>
        Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier) ?? throw AppException.Unauthorized("Sign in again."));

    public static UserRole Role(this ClaimsPrincipal user) =>
        Enum.Parse<UserRole>(user.FindFirstValue(ClaimTypes.Role) ?? nameof(UserRole.Passenger));
}

/// <summary>Turns AppException into a ProblemDetails body whose "detail" the apps show to the user as-is.</summary>
public class AppExceptionHandler(ILogger<AppExceptionHandler> logger, IProblemDetailsService problems) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
    {
        var (status, detail) = ex switch
        {
            AppException a => (a.Status, a.Message),
            DbUpdateConcurrencyException => (409, "Someone else just changed this. Refresh and try again."),
            _ => (500, "Something went wrong on our side. Please try again.")
        };
        if (status == 500) logger.LogError(ex, "Unhandled error on {Path}", ctx.Request.Path);

        ctx.Response.StatusCode = status;
        return await problems.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = ctx,
            ProblemDetails = new ProblemDetails { Status = status, Title = ReasonPhrase(status), Detail = detail }
        });
    }

    private static string ReasonPhrase(int status) => status switch
    {
        400 => "Bad request", 401 => "Unauthorized", 403 => "Forbidden", 404 => "Not found",
        409 => "Conflict", 428 => "Verification required", 501 => "Not available yet", _ => "Error"
    };
}

/// <summary>Stores uploaded images under wwwroot/uploads and returns a public URL path.</summary>
public class FileStore(IWebHostEnvironment env)
{
    private static readonly string[] Allowed = [".jpg", ".jpeg", ".png", ".webp", ".pdf"];
    public const long MaxBytes = 8 * 1024 * 1024;

    public async Task<string> SaveAsync(IFormFile file, string folder, CancellationToken ct)
    {
        if (file.Length == 0) throw AppException.BadRequest("The file is empty.");
        if (file.Length > MaxBytes) throw AppException.BadRequest("Files must be 8 MB or smaller.");
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!Allowed.Contains(ext)) throw AppException.BadRequest("Upload a JPG, PNG, WEBP or PDF file.");

        var root = env.WebRootPath ?? Path.Combine(env.ContentRootPath, "wwwroot");
        var dir = Path.Combine(root, "uploads", folder);
        Directory.CreateDirectory(dir);
        var name = $"{Guid.NewGuid():N}{ext}";
        await using (var fs = File.Create(Path.Combine(dir, name)))
            await file.CopyToAsync(fs, ct);
        return $"/uploads/{folder}/{name}";
    }
}
