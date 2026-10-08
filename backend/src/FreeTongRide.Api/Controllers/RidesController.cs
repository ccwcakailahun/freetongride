using FreeTongRide.Api.Infrastructure;
using FreeTongRide.Application.Common;
using FreeTongRide.Application.Drivers;
using FreeTongRide.Application.Rides;
using FreeTongRide.Application.Wallet;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreeTongRide.Api.Controllers;

/// <summary>Ride endpoints used by both apps. Passenger-only actions are role-guarded.</summary>
[ApiController]
[Route("api/rides")]
[Authorize]
public class RidesController(RideService rides) : ControllerBase
{
    [HttpPost("estimate")]
    public Task<List<ServiceQuote>> Estimate(EstimateRequest r, CancellationToken ct) => rides.EstimateAsync(r, ct);

    [HttpPost]
    [Authorize(Roles = "Passenger")]
    public Task<RideDto> Create(CreateRideRequest r, CancellationToken ct) => rides.CreateAsync(User.UserId(), r, ct);

    /// <summary>The caller's ride in progress, or 204 if none. Apps call this on launch to resume a trip.</summary>
    [HttpGet("current")]
    public async Task<ActionResult<RideDto>> Current(CancellationToken ct) =>
        await rides.CurrentAsync(User.UserId(), User.Role(), ct) is { } ride ? ride : NoContent();

    [HttpGet]
    public Task<PagedResult<RideDto>> History([FromQuery] string? filter, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        rides.HistoryAsync(User.UserId(), User.Role(), filter, Math.Max(1, page), Math.Clamp(pageSize, 1, 50), ct);

    [HttpGet("{id:guid}")]
    public Task<RideDto> Get(Guid id, CancellationToken ct) => rides.GetAsync(User.UserId(), User.Role(), id, ct);

    [HttpGet("{id:guid}/bids")]
    [Authorize(Roles = "Passenger")]
    public Task<List<BidDto>> Bids(Guid id, CancellationToken ct) => rides.BidsAsync(User.UserId(), id, ct);

    [HttpPost("bids/{bidId:guid}/accept")]
    [Authorize(Roles = "Passenger")]
    public Task<RideDto> AcceptBid(Guid bidId, CancellationToken ct) => rides.AcceptBidAsync(User.UserId(), bidId, ct);

    [HttpPost("bids/{bidId:guid}/decline")]
    [Authorize(Roles = "Passenger")]
    public async Task<IActionResult> DeclineBid(Guid bidId, CancellationToken ct)
    {
        await rides.DeclineBidAsync(User.UserId(), bidId, ct);
        return NoContent();
    }

    [HttpPost("{id:guid}/cancel")]
    public Task<RideDto> Cancel(Guid id, CancelRideRequest r, CancellationToken ct) => rides.CancelAsync(User.UserId(), User.Role(), id, r.Reason, ct);

    [HttpPost("{id:guid}/pay")]
    [Authorize(Roles = "Passenger")]
    public Task<RideDto> Pay(Guid id, PayRideRequest r, CancellationToken ct) => rides.PayAsync(User.UserId(), id, r, ct);

    [HttpPost("{id:guid}/rate")]
    public async Task<IActionResult> Rate(Guid id, RateRequest r, CancellationToken ct)
    {
        await rides.RateAsync(User.UserId(), User.Role(), id, r, ct);
        return NoContent();
    }

    [HttpPost("{id:guid}/sos")]
    public async Task<IActionResult> Sos(Guid id, SosRequest r, CancellationToken ct)
    {
        await rides.SosAsync(User.UserId(), User.Role(), id, r, ct);
        return Accepted();
    }

    [HttpGet("{id:guid}/messages")]
    public Task<List<MessageDto>> Messages(Guid id, CancellationToken ct) => rides.MessagesAsync(User.UserId(), User.Role(), id, ct);

    [HttpPost("{id:guid}/messages")]
    public Task<MessageDto> SendMessage(Guid id, MessageRequest r, CancellationToken ct) => rides.SendMessageAsync(User.UserId(), User.Role(), id, r.Text, ct);
}

[ApiController]
[Route("api/services")]
public class ServicesController(DriverOnboardingService onboarding) : ControllerBase
{
    [HttpGet]
    public Task<List<ServiceDto>> List(CancellationToken ct) => onboarding.ServicesAsync(ct);
}

[ApiController]
[Route("api/wallet")]
[Authorize]
public class WalletController(WalletService wallet, IWebHostEnvironment env) : ControllerBase
{
    [HttpGet]
    public Task<WalletSummaryDto> Summary(CancellationToken ct) => wallet.SummaryAsync(User.UserId(), ct);

    [HttpGet("transactions")]
    public Task<PagedResult<WalletTxDto>> History([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        wallet.HistoryAsync(User.UserId(), Math.Max(1, page), Math.Clamp(pageSize, 1, 50), ct);

    /// <summary>Only available in Development until the Orange Money / card gateway is connected.</summary>
    [HttpPost("top-up")]
    public async Task<ActionResult<WalletSummaryDto>> TopUp(TopUpRequest r, CancellationToken ct)
    {
        if (!env.IsDevelopment())
            return Problem(statusCode: 501, title: "Not available yet", detail: "Adding funds with Orange Money is coming soon.");
        return await wallet.DevTopUpAsync(User.UserId(), r, ct);
    }
}
