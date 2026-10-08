using FreeTongRide.Api.Infrastructure;
using FreeTongRide.Application.Drivers;
using FreeTongRide.Application.Rides;
using FreeTongRide.Application.Wallet;
using FreeTongRide.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreeTongRide.Api.Controllers;

public record OnlineRequest(bool Online, LocationUpdate? Location);

[ApiController]
[Route("api/driver")]
[Authorize(Roles = "Driver")]
public class DriverController(DriverOnboardingService onboarding, RideService rides, WalletService wallet, FileStore files) : ControllerBase
{
    // Onboarding
    [HttpGet("profile")]
    public Task<DriverProfileDto> Profile(CancellationToken ct) => onboarding.GetAsync(User.UserId(), ct);

    [HttpPut("vehicle")]
    public Task<DriverProfileDto> Vehicle(UpdateVehicleRequest r, CancellationToken ct) => onboarding.UpdateVehicleAsync(User.UserId(), r, ct);

    [HttpPost("documents/{type}")]
    [RequestSizeLimit(FileStore.MaxBytes + 4096)]
    public async Task<DriverProfileDto> Document(DocumentType type, IFormFile file, CancellationToken ct) =>
        await onboarding.AddDocumentAsync(User.UserId(), type, await files.SaveAsync(file, "driver-docs", ct), ct);

    [HttpPost("submit")]
    public Task<DriverProfileDto> Submit(CancellationToken ct) => onboarding.SubmitAsync(User.UserId(), ct);

    // Availability
    [HttpPost("online")]
    public async Task<IActionResult> Online(OnlineRequest r, CancellationToken ct)
    {
        await rides.SetOnlineAsync(User.UserId(), r.Online, r.Location, ct);
        return NoContent();
    }

    [HttpPost("location")]
    public async Task<IActionResult> Location(LocationUpdate r, CancellationToken ct)
    {
        await rides.UpdateLocationAsync(User.UserId(), r, ct);
        return NoContent();
    }

    // Requests & offers
    [HttpGet("requests")]
    public Task<List<RideRequestDto>> Requests(CancellationToken ct) => rides.OpenRequestsAsync(User.UserId(), ct);

    [HttpPost("requests/{rideId:guid}/bid")]
    public Task<BidDto> Bid(Guid rideId, PlaceBidRequest r, CancellationToken ct) => rides.PlaceBidAsync(User.UserId(), rideId, r.Amount, ct);

    [HttpDelete("requests/{rideId:guid}/bid")]
    public async Task<IActionResult> WithdrawBid(Guid rideId, CancellationToken ct)
    {
        await rides.WithdrawBidAsync(User.UserId(), rideId, ct);
        return NoContent();
    }

    // Trip
    [HttpPost("rides/{id:guid}/arrived")]
    public Task<RideDto> Arrived(Guid id, CancellationToken ct) => rides.ArrivedAsync(User.UserId(), id, ct);

    [HttpPost("rides/{id:guid}/start")]
    public Task<RideDto> Start(Guid id, StartRideRequest r, CancellationToken ct) => rides.StartAsync(User.UserId(), id, r.Code, ct);

    [HttpPost("rides/{id:guid}/end")]
    public Task<RideDto> End(Guid id, CancellationToken ct) => rides.EndAsync(User.UserId(), id, ct);

    [HttpPost("rides/{id:guid}/cash-received")]
    public Task<RideDto> CashReceived(Guid id, CancellationToken ct) => rides.ConfirmCashAsync(User.UserId(), id, ct);

    // Money
    [HttpGet("earnings")]
    public Task<EarningsDto> Earnings(CancellationToken ct) => wallet.EarningsAsync(User.UserId(), ct);

    [HttpGet("withdrawals")]
    public Task<List<WithdrawalDto>> Withdrawals(CancellationToken ct) => wallet.WithdrawalsAsync(User.UserId(), ct);

    [HttpPost("withdrawals")]
    public Task<WithdrawalDto> Withdraw(WithdrawRequest r, CancellationToken ct) => wallet.RequestWithdrawalAsync(User.UserId(), r, ct);
}
