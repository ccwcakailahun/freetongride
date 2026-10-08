using System.Security.Cryptography;
using System.Text;
using FreeTongRide.Application.Common;
using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Auth;

public record RegisterRequest(string FullName, string Phone, string? Email, string Password, UserRole Role = UserRole.Passenger);
public record LoginRequest(string Phone, string Password);
public record SendOtpRequest(string Phone, OtpPurpose Purpose = OtpPurpose.VerifyPhone);
public record VerifyPhoneRequest(string Phone, string Code);
public record ResetPasswordRequest(string Phone, string Code, string NewPassword);
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);

/// <summary>DevCode is only filled when the API runs with Auth:ExposeOtpInResponse (local development without SMS).</summary>
public record OtpSentResponse(string Phone, int ResendAfterSeconds, string? DevCode);
public record AuthResponse(string AccessToken, DateTime ExpiresAt, UserDto User);

public record UserDto(
    Guid Id, string FullName, string Phone, string? Email, UserRole Role, bool PhoneVerified,
    string? PhotoUrl, string? EmergencyContact, string? HomeArea, decimal WalletBalance, int Points,
    double Rating, int RatingCount, DateTime CreatedAt)
{
    public static UserDto From(User u) => new(u.Id, u.FullName, u.Phone, u.Email, u.Role, u.PhoneVerified,
        u.PhotoUrl, u.EmergencyContact, u.HomeArea, u.WalletBalance, u.Points, u.Rating, u.RatingCount, u.CreatedAt);
}

public class AuthSettings
{
    public bool ExposeOtpInResponse { get; set; }
    public int OtpMinutes { get; set; } = 10;
    public int OtpResendSeconds { get; set; } = 60;
    public int OtpMaxAttempts { get; set; } = 5;
}

public class AuthService(IAppDbContext db, IPasswordService passwords, ITokenService tokens, ISmsSender sms, AuthSettings settings)
{
    public async Task<OtpSentResponse> RegisterAsync(RegisterRequest r, CancellationToken ct)
    {
        if (r.Role == UserRole.Admin) throw AppException.Forbidden("Admin accounts are created by an administrator.");
        if (string.IsNullOrWhiteSpace(r.FullName) || r.FullName.Trim().Length < 2) throw AppException.BadRequest("Enter your full name.");
        ValidatePassword(r.Password);
        var phone = Phone.Normalize(r.Phone);
        var email = string.IsNullOrWhiteSpace(r.Email) ? null : r.Email.Trim().ToLowerInvariant();

        var existing = await db.Users.FirstOrDefaultAsync(u => u.Phone == phone, ct);
        if (existing is { PhoneVerified: true }) throw AppException.Conflict("An account with this phone number already exists. Sign in instead.");
        if (email != null && await db.Users.AnyAsync(u => u.Email == email && u.Phone != phone, ct))
            throw AppException.Conflict("This email is already used by another account.");

        // An unverified account can be re-registered (e.g. the person mistyped and came back).
        var user = existing ?? new User { Phone = phone };
        user.FullName = r.FullName.Trim();
        user.Email = email;
        user.Role = r.Role;
        user.PasswordHash = passwords.Hash(user, r.Password);
        if (existing == null)
        {
            db.Users.Add(user);
            if (r.Role == UserRole.Driver) db.DriverProfiles.Add(new DriverProfile { UserId = user.Id });
        }
        await db.SaveChangesAsync(ct);

        return await SendOtpAsync(new SendOtpRequest(phone), ct);
    }

    public async Task<OtpSentResponse> SendOtpAsync(SendOtpRequest r, CancellationToken ct)
    {
        var phone = Phone.Normalize(r.Phone);
        var user = await db.Users.FirstOrDefaultAsync(u => u.Phone == phone, ct);
        // Do not reveal whether a number is registered for password resets.
        if (user == null && r.Purpose == OtpPurpose.ResetPassword)
            return new OtpSentResponse(phone, settings.OtpResendSeconds, null);
        if (user == null) throw AppException.NotFound("Create an account first.");

        var last = await db.OtpCodes.Where(o => o.Phone == phone && o.Purpose == r.Purpose)
            .OrderByDescending(o => o.CreatedAt).FirstOrDefaultAsync(ct);
        if (last != null && last.CreatedAt > DateTime.UtcNow.AddSeconds(-settings.OtpResendSeconds))
        {
            var wait = settings.OtpResendSeconds - (int)(DateTime.UtcNow - last.CreatedAt).TotalSeconds;
            throw AppException.BadRequest($"Please wait {wait} seconds before requesting a new code.");
        }

        var code = Codes.Numeric(6);
        db.OtpCodes.Add(new OtpCode
        {
            Phone = phone, Purpose = r.Purpose, CodeHash = HashCode(phone, r.Purpose, code),
            ExpiresAt = DateTime.UtcNow.AddMinutes(settings.OtpMinutes)
        });
        await db.SaveChangesAsync(ct);
        await sms.SendAsync(phone, $"Your FreeTongRide code is {code}. It expires in {settings.OtpMinutes} minutes. Never share it.", ct);

        return new OtpSentResponse(phone, settings.OtpResendSeconds, settings.ExposeOtpInResponse ? code : null);
    }

    public async Task<AuthResponse> VerifyPhoneAsync(VerifyPhoneRequest r, CancellationToken ct)
    {
        var phone = Phone.Normalize(r.Phone);
        await ConsumeOtpAsync(phone, OtpPurpose.VerifyPhone, r.Code, ct);
        var user = await db.Users.FirstAsync(u => u.Phone == phone, ct);
        user.PhoneVerified = true;
        user.LastLoginAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return Issue(user);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest r, UserRole? requiredRole, CancellationToken ct)
    {
        var phoneOrEmail = r.Phone.Trim();
        User? user;
        if (phoneOrEmail.Contains('@'))
            user = await db.Users.FirstOrDefaultAsync(u => u.Email == phoneOrEmail.ToLower(), ct);
        else
            user = await db.Users.FirstOrDefaultAsync(u => u.Phone == Phone.Normalize(phoneOrEmail), ct);

        if (user == null || !passwords.Verify(user, r.Password))
            throw AppException.Unauthorized("Phone number or password is incorrect.");
        if (requiredRole != null && user.Role != requiredRole)
            throw AppException.Forbidden(requiredRole switch
            {
                UserRole.Driver => "This account is not a driver account.",
                UserRole.Admin => "This account cannot access the admin panel.",
                _ => "Use the driver app to sign in with a driver account."
            });
        if (!user.IsActive) throw AppException.Forbidden("This account is suspended. Contact FreeTongRide support.");
        if (!user.PhoneVerified) throw new AppException(428, "Verify your phone number to continue.");

        user.LastLoginAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        return Issue(user);
    }

    public async Task ResetPasswordAsync(ResetPasswordRequest r, CancellationToken ct)
    {
        ValidatePassword(r.NewPassword);
        var phone = Phone.Normalize(r.Phone);
        await ConsumeOtpAsync(phone, OtpPurpose.ResetPassword, r.Code, ct);
        var user = await db.Users.FirstAsync(u => u.Phone == phone, ct);
        user.PasswordHash = passwords.Hash(user, r.NewPassword);
        user.PhoneVerified = true;
        await db.SaveChangesAsync(ct);
    }

    public async Task ChangePasswordAsync(Guid userId, ChangePasswordRequest r, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        if (!passwords.Verify(user, r.CurrentPassword)) throw AppException.BadRequest("Current password is incorrect.");
        ValidatePassword(r.NewPassword);
        user.PasswordHash = passwords.Hash(user, r.NewPassword);
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Same rules as the Create Password screen: 8+ characters, one number, one uppercase letter.</summary>
    public static void ValidatePassword(string? p)
    {
        if (string.IsNullOrEmpty(p) || p.Length < 8 || !p.Any(char.IsDigit) || !p.Any(char.IsUpper))
            throw AppException.BadRequest("Password must have at least 8 characters, one number and one uppercase letter.");
    }

    private async Task ConsumeOtpAsync(string phone, OtpPurpose purpose, string code, CancellationToken ct)
    {
        var otp = await db.OtpCodes.Where(o => o.Phone == phone && o.Purpose == purpose && !o.Used)
            .OrderByDescending(o => o.CreatedAt).FirstOrDefaultAsync(ct);
        if (otp == null || otp.ExpiresAt < DateTime.UtcNow) throw AppException.BadRequest("This code has expired. Request a new one.");
        if (otp.Attempts >= settings.OtpMaxAttempts) throw AppException.BadRequest("Too many wrong attempts. Request a new code.");

        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(otp.CodeHash), Encoding.UTF8.GetBytes(HashCode(phone, purpose, (code ?? "").Trim()))))
        {
            otp.Attempts++;
            await db.SaveChangesAsync(ct);
            throw AppException.BadRequest("That code is not correct. Check the SMS and try again.");
        }
        otp.Used = true;
    }

    private AuthResponse Issue(User user)
    {
        var t = tokens.Issue(user);
        return new AuthResponse(t.AccessToken, t.ExpiresAt, UserDto.From(user));
    }

    private static string HashCode(string phone, OtpPurpose purpose, string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{phone}:{(int)purpose}:{code}")));
}
