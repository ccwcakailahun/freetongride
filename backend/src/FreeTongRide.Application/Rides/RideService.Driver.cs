using FreeTongRide.Application.Common;
using FreeTongRide.Application.Wallet;
using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Rides;

/// <summary>Driver-side ride actions.</summary>
public partial class RideService
{
    public async Task SetOnlineAsync(Guid driverId, bool online, LocationUpdate? at, CancellationToken ct)
    {
        var p = await DriverAsync(driverId, ct);
        if (online && p.Status != DriverStatus.Approved)
            throw AppException.Forbidden("Your account must be approved before you can go online.");
        if (online && p.ServiceId == null) throw AppException.BadRequest("Choose your ride type first.");
        p.IsOnline = online;
        if (at != null) { p.Lat = at.Lat; p.Lng = at.Lng; p.Heading = at.Heading; }
        p.LastSeenAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        await realtime.ToAdmins("driver.status", new { driverId, online, p.Lat, p.Lng });
    }

    public async Task UpdateLocationAsync(Guid driverId, LocationUpdate loc, CancellationToken ct)
    {
        var p = await DriverAsync(driverId, ct);
        p.Lat = loc.Lat;
        p.Lng = loc.Lng;
        p.Heading = loc.Heading;
        p.LastSeenAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);

        var payload = new { driverId, lat = loc.Lat, lng = loc.Lng, heading = loc.Heading, at = p.LastSeenAt };
        var ride = await db.Rides.Where(r => r.DriverId == driverId &&
                (r.Status == RideStatus.DriverAssigned || r.Status == RideStatus.DriverArrived || r.Status == RideStatus.InProgress))
            .Select(r => new { r.Id, r.PassengerId }).FirstOrDefaultAsync(ct);
        if (ride != null) await realtime.ToUser(ride.PassengerId, RideEvents.DriverLocation, new { rideId = ride.Id, payload.lat, payload.lng, payload.heading });
        await realtime.ToAdmins(RideEvents.DriverLocation, new { rideId = ride?.Id, payload.driverId, payload.lat, payload.lng, payload.heading });
    }

    /// <summary>Open requests near the driver for their ride type, newest first.</summary>
    public async Task<List<RideRequestDto>> OpenRequestsAsync(Guid driverId, CancellationToken ct)
    {
        var p = await DriverAsync(driverId, ct);
        if (p.Lat == null || p.Lng == null || p.ServiceId == null) return [];
        var since = DateTime.UtcNow.AddMinutes(-15);
        var rides = await db.Rides.Include(r => r.Passenger).Include(r => r.Service)
            .Where(r => r.Status == RideStatus.Searching && r.ServiceId == p.ServiceId && r.CreatedAt >= since && r.PassengerId != driverId)
            .OrderByDescending(r => r.CreatedAt).Take(50).ToListAsync(ct);
        var myBids = await db.Bids.Where(b => b.DriverId == driverId && b.Status == BidStatus.Pending)
            .ToDictionaryAsync(b => b.RideId, b => b.Amount, ct);

        return rides
            .Where(r => Geo.HaversineKm(p.Lat.Value, p.Lng.Value, r.PickupLat, r.PickupLng) <= RequestRadiusKm)
            .Select(r => ToRequestDto(r, p.Lat.Value, p.Lng.Value, myBids.TryGetValue(r.Id, out var a) ? a : null))
            .ToList();
    }

    public async Task<BidDto> PlaceBidAsync(Guid driverId, Guid rideId, decimal amount, CancellationToken ct)
    {
        var p = await DriverAsync(driverId, ct);
        if (p.Status != DriverStatus.Approved || !p.IsOnline) throw AppException.Forbidden("Go online to send offers.");
        if (await db.Rides.AnyAsync(r => r.DriverId == driverId && ActiveStatuses.Contains(r.Status), ct))
            throw AppException.Conflict("Finish your current trip first.");

        var ride = await db.Rides.Include(r => r.Service).FirstOrDefaultAsync(r => r.Id == rideId, ct)
                   ?? throw AppException.NotFound("This request is no longer available.");
        if (ride.Status != RideStatus.Searching) throw AppException.Conflict("This request has been taken or cancelled.");
        if (ride.ServiceId != p.ServiceId) throw AppException.Forbidden("This request is for a different ride type.");
        amount = Math.Ceiling(amount);
        if (amount < ride.OfferedFare) throw AppException.BadRequest($"Your offer cannot be lower than the passenger's Le {ride.OfferedFare:N0}.");
        if (amount > ride.OfferedFare * 2) throw AppException.BadRequest("Your offer is too high for this trip.");

        var eta = p.Lat == null ? 5 : EtaMinutes(Geo.HaversineKm(p.Lat.Value, p.Lng!.Value, ride.PickupLat, ride.PickupLng));
        var bid = await db.Bids.FirstOrDefaultAsync(b => b.RideId == rideId && b.DriverId == driverId && b.Status == BidStatus.Pending, ct);
        if (bid == null)
        {
            bid = new Bid { RideId = rideId, DriverId = driverId };
            db.Bids.Add(bid);
        }
        bid.Amount = amount;
        bid.EtaMinutes = eta;
        await db.SaveChangesAsync(ct);

        bid.Driver = await db.Users.Include(u => u.DriverProfile).FirstAsync(u => u.Id == driverId, ct);
        var dto = RideMapping.ToDto(bid);
        await realtime.ToUser(ride.PassengerId, RideEvents.NewBid, dto);
        return dto;
    }

    public async Task WithdrawBidAsync(Guid driverId, Guid rideId, CancellationToken ct)
    {
        var bid = await db.Bids.Include(b => b.Ride)
            .FirstOrDefaultAsync(b => b.RideId == rideId && b.DriverId == driverId && b.Status == BidStatus.Pending, ct);
        if (bid == null) return;
        bid.Status = BidStatus.Withdrawn;
        await db.SaveChangesAsync(ct);
        await realtime.ToUser(bid.Ride.PassengerId, RideEvents.BidWithdrawn, new { bidId = bid.Id, rideId });
    }

    public async Task<RideDto> ArrivedAsync(Guid driverId, Guid rideId, CancellationToken ct)
    {
        var ride = await LoadForAsync(driverId, UserRole.Driver, rideId, ct);
        if (ride.Status != RideStatus.DriverAssigned) throw AppException.Conflict("You can mark arrival only on the way to pickup.");
        ride.Status = RideStatus.DriverArrived;
        ride.ArrivedAt = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
        await NotifyPartiesAsync(ride);
        return RideMapping.ToDto(ride, false);
    }

    public async Task<RideDto> StartAsync(Guid driverId, Guid rideId, string code, CancellationToken ct)
    {
        var ride = await LoadForAsync(driverId, UserRole.Driver, rideId, ct);
        if (ride.Status is not (RideStatus.DriverAssigned or RideStatus.DriverArrived))
            throw AppException.Conflict("This trip cannot be started now.");
        if ((code ?? "").Trim() != ride.PickupCode)
            throw AppException.BadRequest("That code is not correct. Ask the passenger for the 6-digit code in their app.");
        ride.Status = RideStatus.InProgress;
        ride.StartedAt = DateTime.UtcNow;
        ride.ArrivedAt ??= ride.StartedAt;
        await db.SaveChangesAsync(ct);
        await NotifyPartiesAsync(ride);
        return RideMapping.ToDto(ride, false);
    }

    /// <summary>Ends the trip. Wallet rides with enough balance settle at once; otherwise the ride waits for payment.</summary>
    public async Task<RideDto> EndAsync(Guid driverId, Guid rideId, CancellationToken ct)
    {
        var ride = await LoadForAsync(driverId, UserRole.Driver, rideId, ct);
        if (ride.Status != RideStatus.InProgress) throw AppException.Conflict("Only a running trip can be ended.");
        ride.Status = RideStatus.AwaitingPayment;
        ride.EndedAt = DateTime.UtcNow;
        if (ride.PaymentMethod == PaymentMethod.Wallet && ride.Passenger.WalletBalance >= ride.FareDue)
            WalletService.Settle(db, ride, ride.Passenger, ride.Driver!, PaymentMethod.Wallet);
        await db.SaveChangesAsync(ct);
        await NotifyPartiesAsync(ride);
        return RideMapping.ToDto(ride, false);
    }

    public async Task<RideDto> ConfirmCashAsync(Guid driverId, Guid rideId, CancellationToken ct)
    {
        var ride = await LoadForAsync(driverId, UserRole.Driver, rideId, ct);
        if (ride.Status != RideStatus.AwaitingPayment) throw AppException.Conflict("This ride is not waiting for payment.");
        WalletService.Settle(db, ride, ride.Passenger, ride.Driver!, PaymentMethod.Cash);
        await db.SaveChangesAsync(ct);
        await NotifyPartiesAsync(ride);
        return RideMapping.ToDto(ride, false);
    }

    private async Task<DriverProfile> DriverAsync(Guid driverId, CancellationToken ct) =>
        await db.DriverProfiles.FirstOrDefaultAsync(d => d.UserId == driverId, ct)
        ?? throw AppException.Forbidden("This account is not a driver account.");
}
