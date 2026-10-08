using FreeTongRide.Api.Infrastructure;
using FreeTongRide.Application.Admin;
using FreeTongRide.Application.Common;
using FreeTongRide.Application.Drivers;
using FreeTongRide.Application.Rides;
using FreeTongRide.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FreeTongRide.Api.Controllers;

public record SosUpdateRequest(SosStatus Status, string? Note);
public record ActiveRequest(bool Active);
public record SuspendRequest(bool Suspended);

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController(AdminService admin) : ControllerBase
{
    [HttpGet("dashboard")]
    public Task<DashboardDto> Dashboard(CancellationToken ct) => admin.DashboardAsync(ct);

    [HttpGet("live")]
    public Task<LiveMapDto> Live(CancellationToken ct) => admin.LiveMapAsync(ct);

    // Rides
    [HttpGet("rides")]
    public Task<PagedResult<RideDto>> Rides([FromQuery] RideStatus? status, [FromQuery] string? search, [FromQuery] DateTime? from,
        [FromQuery] DateTime? to, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        admin.RidesAsync(status, search, from, to, Math.Max(1, page), Math.Clamp(pageSize, 1, 100), ct);

    [HttpGet("rides/{id:guid}")]
    public Task<AdminRideDetail> Ride(Guid id, CancellationToken ct) => admin.RideAsync(id, ct);

    [HttpPost("rides/{id:guid}/cancel")]
    public Task<RideDto> CancelRide(Guid id, CancelRideRequest r, CancellationToken ct) => admin.CancelRideAsync(id, r.Reason, ct);

    // Drivers
    [HttpGet("drivers")]
    public Task<PagedResult<AdminDriverRow>> Drivers([FromQuery] DriverStatus? status, [FromQuery] bool? online, [FromQuery] string? search,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        admin.DriversAsync(status, online, search, Math.Max(1, page), Math.Clamp(pageSize, 1, 100), ct);

    [HttpGet("drivers/{id:guid}")]
    public Task<AdminDriverDetail> Driver(Guid id, CancellationToken ct) => admin.DriverAsync(id, ct);

    [HttpPost("drivers/{id:guid}/review")]
    public Task<AdminDriverDetail> ReviewDriver(Guid id, ReviewDecision d, CancellationToken ct) => admin.ReviewDriverAsync(id, d, ct);

    [HttpPost("drivers/{id:guid}/suspend")]
    public async Task<IActionResult> SuspendDriver(Guid id, SuspendRequest r, CancellationToken ct)
    {
        await admin.SetDriverSuspendedAsync(id, r.Suspended, ct);
        return NoContent();
    }

    // Passengers
    [HttpGet("passengers")]
    public Task<PagedResult<AdminPassengerRow>> Passengers([FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        admin.PassengersAsync(search, Math.Max(1, page), Math.Clamp(pageSize, 1, 100), ct);

    [HttpPost("users/{id:guid}/verify-phone")]
    public async Task<IActionResult> VerifyPhone(Guid id, CancellationToken ct)
    {
        await admin.VerifyPhoneAsync(id, ct);
        return NoContent();
    }

    [HttpPost("users/{id:guid}/active")]
    public async Task<IActionResult> SetActive(Guid id, ActiveRequest r, CancellationToken ct)
    {
        await admin.SetUserActiveAsync(id, r.Active, ct);
        return NoContent();
    }

    // Safety
    [HttpGet("sos")]
    public Task<List<SosDto>> Sos([FromQuery] bool openOnly = false, CancellationToken ct = default) => admin.SosAsync(openOnly, ct);

    [HttpPost("sos/{id:guid}")]
    public Task<SosDto> UpdateSos(Guid id, SosUpdateRequest r, CancellationToken ct) => admin.UpdateSosAsync(id, User.UserId(), r.Status, r.Note, ct);

    // Money
    [HttpGet("withdrawals")]
    public Task<PagedResult<AdminWithdrawalRow>> Withdrawals([FromQuery] WithdrawalStatus? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        admin.WithdrawalsAsync(status, Math.Max(1, page), Math.Clamp(pageSize, 1, 100), ct);

    [HttpPost("withdrawals/{id:guid}")]
    public async Task<IActionResult> ProcessWithdrawal(Guid id, ReviewDecision d, CancellationToken ct)
    {
        await admin.ProcessWithdrawalAsync(id, d, ct);
        return NoContent();
    }

    [HttpGet("transactions")]
    public Task<PagedResult<AdminTxRow>> Transactions([FromQuery] WalletTxType? type, [FromQuery] string? search, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default) =>
        admin.TransactionsAsync(type, search, Math.Max(1, page), Math.Clamp(pageSize, 1, 100), ct);

    // Ride types & fares
    [HttpGet("services")]
    public Task<List<ServiceDto>> Services(CancellationToken ct) => admin.ServicesAsync(ct);

    [HttpPost("services")]
    public Task<ServiceDto> CreateService(SaveServiceRequest r, CancellationToken ct) => admin.SaveServiceAsync(null, r, ct);

    [HttpPut("services/{id:guid}")]
    public Task<ServiceDto> UpdateService(Guid id, SaveServiceRequest r, CancellationToken ct) => admin.SaveServiceAsync(id, r, ct);
}
