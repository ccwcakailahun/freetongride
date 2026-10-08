using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FreeTongRide.Application.Common;
using FreeTongRide.Domain.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

namespace FreeTongRide.Infrastructure.Security;

public class JwtSettings
{
    public string Issuer { get; set; } = "FreeTongRide";
    public string Audience { get; set; } = "FreeTongRide";
    /// <summary>At least 32 characters. Set via configuration or the Jwt__Key environment variable, never committed.</summary>
    public string Key { get; set; } = "";
    public int AccessTokenDays { get; set; } = 30;
}

public class PasswordService : IPasswordService
{
    private readonly PasswordHasher<User> _hasher = new();

    public string Hash(User user, string password) => _hasher.HashPassword(user, password);

    public bool Verify(User user, string password) =>
        !string.IsNullOrEmpty(user.PasswordHash) &&
        _hasher.VerifyHashedPassword(user, user.PasswordHash, password) != PasswordVerificationResult.Failed;
}

public class JwtTokenService(JwtSettings settings) : ITokenService
{
    public AuthTokens Issue(User user)
    {
        var expires = DateTime.UtcNow.AddDays(settings.AccessTokenDays);
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.FullName),
            new Claim(ClaimTypes.MobilePhone, user.Phone),
            new Claim(ClaimTypes.Role, user.Role.ToString()),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        var creds = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.Key)), SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(settings.Issuer, settings.Audience, claims, expires: expires, signingCredentials: creds);
        return new AuthTokens(new JwtSecurityTokenHandler().WriteToken(token), expires);
    }
}

/// <summary>Writes SMS to the log. Replace with a real gateway (e.g. MSG91, Africa's Talking) for production.</summary>
public class LogSmsSender(ILogger<LogSmsSender> logger) : ISmsSender
{
    public Task SendAsync(string phone, string message, CancellationToken ct = default)
    {
        logger.LogInformation("SMS to {Phone}: {Message}", phone, message);
        return Task.CompletedTask;
    }
}
