using FreeTongRide.Api.Infrastructure;
using FreeTongRide.Application.Accounts;
using FreeTongRide.Application.Auth;
using FreeTongRide.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FreeTongRide.Api.Controllers;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("auth")]
public class AuthController(AuthService auth) : ControllerBase
{
    [HttpPost("register")]
    public Task<OtpSentResponse> Register(RegisterRequest r, CancellationToken ct) => auth.RegisterAsync(r, ct);

    [HttpPost("otp")]
    public Task<OtpSentResponse> SendOtp(SendOtpRequest r, CancellationToken ct) => auth.SendOtpAsync(r, ct);

    [HttpPost("verify-phone")]
    public Task<AuthResponse> VerifyPhone(VerifyPhoneRequest r, CancellationToken ct) => auth.VerifyPhoneAsync(r, ct);

    /// <summary>Passenger app sign-in.</summary>
    [HttpPost("login")]
    public Task<AuthResponse> Login(LoginRequest r, CancellationToken ct) => auth.LoginAsync(r, UserRole.Passenger, ct);

    [HttpPost("driver/login")]
    public Task<AuthResponse> DriverLogin(LoginRequest r, CancellationToken ct) => auth.LoginAsync(r, UserRole.Driver, ct);

    [HttpPost("admin/login")]
    public Task<AuthResponse> AdminLogin(LoginRequest r, CancellationToken ct) => auth.LoginAsync(r, UserRole.Admin, ct);

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest r, CancellationToken ct)
    {
        await auth.ResetPasswordAsync(r, ct);
        return NoContent();
    }
}

[ApiController]
[Route("api/me")]
[Authorize]
public class MeController(AccountService accounts, AuthService auth, FileStore files) : ControllerBase
{
    [HttpGet]
    public Task<UserDto> Get(CancellationToken ct) => accounts.GetAsync(User.UserId(), ct);

    [HttpPut]
    public Task<UserDto> Update(UpdateProfileRequest r, CancellationToken ct) => accounts.UpdateAsync(User.UserId(), r, ct);

    [HttpPost("photo")]
    [RequestSizeLimit(FileStore.MaxBytes + 4096)]
    public async Task<UserDto> Photo(IFormFile file, CancellationToken ct) =>
        await accounts.SetPhotoAsync(User.UserId(), await files.SaveAsync(file, "avatars", ct), ct);

    [HttpPost("password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest r, CancellationToken ct)
    {
        await auth.ChangePasswordAsync(User.UserId(), r, ct);
        return NoContent();
    }

    [HttpPost("device-token")]
    public async Task<IActionResult> DeviceToken(DeviceTokenRequest r, CancellationToken ct)
    {
        await accounts.SetDeviceTokenAsync(User.UserId(), r.Token, ct);
        return NoContent();
    }

    [HttpGet("places")]
    public Task<List<SavedPlaceDto>> Places(CancellationToken ct) => accounts.PlacesAsync(User.UserId(), ct);

    [HttpPost("places")]
    public Task<SavedPlaceDto> SavePlace(SavePlaceRequest r, CancellationToken ct) => accounts.SavePlaceAsync(User.UserId(), r, ct);

    [HttpDelete("places/{id:guid}")]
    public async Task<IActionResult> DeletePlace(Guid id, CancellationToken ct)
    {
        await accounts.DeletePlaceAsync(User.UserId(), id, ct);
        return NoContent();
    }
}
