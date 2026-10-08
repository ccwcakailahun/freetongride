using FreeTongRide.Application.Common;
using FreeTongRide.Application.Fares;
using FreeTongRide.Application.Wallet;
using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Rides;

/// <summary>Passenger-side ride actions plus helpers shared with the driver side (RideService.Driver.cs).</summary>
public partial class RideService(IAppDbContext db, IRealtime realtime)
{
    /// <summary>Drivers within this distance of the pickup get the request.</summary>
    public const double RequestRadiusKm = 6;
    /// <summary>A driver whose app has not reported a location for this long is treated as offline.</summary>
    public static readonly TimeSpan DriverStaleAfter = TimeSpan.FromMinutes(3);

    public static readonly RideStatus[] ActiveStatuses =
        [RideStatus.Searching, RideStatus.DriverAssigned, RideStatus.DriverArrived, RideStatus.InProgress, RideStatus.AwaitingPayment];

    // ---------- Passenger ----------

    public async Task<List<ServiceQuote>> EstimateAsync(EstimateRequest r, CancellationToken ct)
    {
        var (km, minutes) = Geo.RoadEstimate(r.Pickup.Lat, r.Pickup.Lng, r.Dropoff.Lat, r.Dropoff.Lng);
        if (km < 0.3) throw AppException.BadRequest("Pickup and drop-off are too close together.");
        var coupon = await FindCouponAsync(r.CouponCode, ct);
        var services = await db.Services.Where(s => s.IsActive).OrderBy(s => s.SortOrder).ToListAsync(ct);
        var drivers = await OnlineDriversAsync(null, ct);

        return services.Select(s =>
        {
            var f = FareCalculator.Calculate(s, km, minutes);
            var near = drivers.Where(d => d.ServiceId == s.Id)
                .Select(d => Geo.HaversineKm(d.Lat!.Value, d.Lng!.Value, r.Pickup.Lat, r.Pickup.Lng))
                .Where(d => d <= RequestRadiusKm).OrderBy(d => d).ToList();
            var discount = coupon == null ? 0 : FareCalculator.CouponDiscount(coupon, f.Total);
            return new ServiceQuote(s.Id, s.Name, s.Description, s.Seats, f.Total, f.BaseFare, f.DistanceFare, f.TimeFare,
                discount, km, minutes, near.Count == 0 ? null : EtaMinutes(near[0]), near.Count);
        }).ToList();
    }

    public async Task<RideDto> CreateAsync(Guid passengerId, CreateRideRequest r, CancellationToken ct)
    {
        if (await db.Rides.AnyAsync(x => x.PassengerId == passengerId && ActiveStatuses.Contains(x.Status), ct))
            throw AppException.Conflict("You already have a ride in progress.");
        if (r.PaymentMethod is PaymentMethod.OrangeMoney or PaymentMethod.Card)
            throw AppException.BadRequest("Orange Money and card payments are coming soon. Choose cash or wallet.");

        var service = await db.Services.FirstOrDefaultAsync(s => s.Id == r.ServiceId && s.IsActive, ct)
                      ?? throw AppException.BadRequest("This ride type is not available.");
        var passenger = await db.Users.FirstAsync(u => u.Id == passengerId, ct);
        var (km, minutes) = Geo.RoadEstimate(r.Pickup.Lat, r.Pickup.Lng, r.Dropoff.Lat, r.Dropoff.Lng);
        if (km < 0.3) throw AppException.BadRequest("Pickup and drop-off are too close together.");
        var estimate = FareCalculator.Calculate(service, km, minutes).Total;

        var offered = r.OfferedFare ?? estimate;
        var floor = Math.Max(service.MinimumFare, Math.Floor(estimate * 0.7m));
        if (offered < floor) throw AppException.BadRequest($"The lowest fare you can offer for this trip is Le {floor:N0}.");
        if (offered > estimate * 3) throw AppException.BadRequest("That offer is much higher than this trip normally costs.");

        var coupon = await FindCouponAsync(r.CouponCode, ct);
        var ride = new Ride
        {
            Code = Codes.RideCode(),
            PassengerId = passengerId, Passenger = passenger, ServiceId = service.Id, Service = service,
            PickupAddress = r.Pickup.Address, PickupLat = r.Pickup.Lat, PickupLng = r.Pickup.Lng,
            DropoffAddress = r.Dropoff.Address, DropoffLat = r.Dropoff.Lat, DropoffLng = r.Dropoff.Lng,
            DistanceKm = km, DurationMinutes = minutes, EstimatedFare = estimate, OfferedFare = Math.Ceiling(offered),
            PaymentMethod = r.PaymentMethod, PickupCode = Codes.Numeric(6), Status = RideStatus.Searching,
            ForSomeoneElse = r.ForSomeoneElse, RiderName = r.RiderName?.Trim(),
            RiderPhone = string.IsNullOrWhiteSpace(r.RiderPhone) ? null : Phone.Normalize(r.RiderPhone),
            Note = r.Note?.Trim()
        };
        if (coupon != null)
        {
            ride.CouponCode = coupon.Code;
            ride.Discount = FareCalculator.CouponDiscount(coupon, ride.OfferedFare);
            coupon.TimesUsed++;
        }
        if (r.PaymentMethod == PaymentMethod.Wallet && passenger.WalletBalance < ride.FareDue)
            throw AppException.BadRequest($"Your wallet has Le {passenger.WalletBalance:N0}. Add funds or choose cash.");

        db.Rides.Add(ride);
        await db.SaveChangesAsync(ct);

        var nearby = (await OnlineDriversAsync(service.Id, ct))
            .Where(d => Geo.HaversineKm(d.Lat!.Value, d.Lng!.Value, ride.PickupLat, ride.PickupLng) <= RequestRadiusKm)
            .ToList();
        foreach (var d in nearby)
            await realtime.ToUser(d.UserId, RideEvents.NewRequest, ToRequestDto(ride, d.Lat!.Value, d.Lng!.Value, null));
        await realtime.ToAdmins(RideEvents.Updated, RideMapping.ToDto(ride, false));

        return RideMapping.ToDto(ride, true);
    }

    public async Task<RideDto?> CurrentAsync(Guid userId, UserRole role, CancellationToken ct)
    {
        var ride = await Rides()
            .Where(r => (role == UserRole.Driver ? r.DriverId == userId : r.PassengerId == userId) && ActiveStatuses.Contains(r.Status))
            .OrderByDescending(r => r.CreatedAt).FirstOrDefaultAsync(ct);
        return ride == null ? null : RideMapping.ToDto(ride, role == UserRole.Passenger);
    }

    public async Task<RideDto> GetAsync(Guid userId, UserRole role, Guid rideId, CancellationToken ct)
    {
        var ride = await LoadForAsync(userId, role, rideId, ct);
        var rating = await db.Reviews.Where(x => x.RideId == rideId && x.FromUserId == userId).Select(x => (int?)x.Stars).FirstOrDefaultAsync(ct);
        return RideMapping.ToDto(ride, role == UserRole.Passenger, rating);
    }

    /// <param name="filter">all, upcoming (active) or completed (completed + cancelled).</param>
    public async Task<PagedResult<RideDto>> HistoryAsync(Guid userId, UserRole role, string? filter, int page, int pageSize, CancellationToken ct)
    {
        var q = Rides().Where(r => role == UserRole.Driver ? r.DriverId == userId : r.PassengerId == userId);
        q = filter switch
        {
            "upcoming" => q.Where(r => ActiveStatuses.Contains(r.Status)),
            "completed" => q.Where(r => r.Status == RideStatus.Completed || r.Status == RideStatus.Cancelled),
            _ => q
        };
        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(r => r.CreatedAt).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        var ids = items.Select(i => i.Id).ToList();
        var ratings = await db.Reviews.Where(x => ids.Contains(x.RideId) && x.FromUserId == userId).ToDictionaryAsync(x => x.RideId, x => x.Stars, ct);
        return new PagedResult<RideDto>(
            items.Select(r => RideMapping.ToDto(r, false, ratings.TryGetValue(r.Id, out var s) ? s : null)).ToList(), total, page, pageSize);
    }

    public async Task<List<BidDto>> BidsAsync(Guid passengerId, Guid rideId, CancellationToken ct)
    {
        await LoadForAsync(passengerId, UserRole.Passenger, rideId, ct);
        var bids = await db.Bids.Include(b => b.Driver).ThenInclude(d => d.DriverProfile)
            .Where(b => b.RideId == rideId && b.Status == BidStatus.Pending)
            .OrderBy(b => b.Amount).ThenBy(b => b.EtaMinutes).ToListAsync(ct);
        return bids.Select(RideMapping.ToDto).ToList();
    }

    public async Task<RideDto> AcceptBidAsync(Guid passengerId, Guid bidId, CancellationToken ct)
    {
        var bid = await db.Bids.Include(b => b.Driver).ThenInclude(d => d.DriverProfile)
            .FirstOrDefaultAsync(b => b.Id == bidId, ct) ?? throw AppException.NotFound("This offer is no longer available.");
        var ride = await LoadForAsync(passengerId, UserRole.Passenger, bid.RideId, ct);
        if (ride.Status != RideStatus.Searching) throw AppException.Conflict("A driver has already been chosen for this ride.");
        if (bid.Status != BidStatus.Pending) throw AppException.Conflict("This offer is no longer available.");
        if (await db.Rides.AnyAsync(r => r.DriverId == bid.DriverId && ActiveStatuses.Contains(r.Status) && r.Id != ride.Id, ct))
            throw AppException.Conflict("This driver just took another trip. Choose another offer.");

        var passenger = ride.Passenger;
        if (ride.PaymentMethod == PaymentMethod.Wallet && passenger.WalletBalance < bid.Amount - (ride.Discount ?? 0))
            throw AppException.BadRequest("Your wallet balance does not cover this offer. Add funds or pick a lower offer.");

        bid.Status = BidStatus.Accepted;
        ride.Driver = bid.Driver;
        ride.DriverId = bid.DriverId;
        ride.AgreedFare = bid.Amount;
        ride.Status = RideStatus.DriverAssigned;
        ride.AssignedAt = DateTime.UtcNow;

        var losers = await db.Bids.Where(b => b.RideId == ride.Id && b.Id != bid.Id && b.Status == BidStatus.Pending).ToListAsync(ct);
        losers.ForEach(b => b.Status = BidStatus.Declined);
        await db.SaveChangesAsync(ct); // RowVersion on Ride rejects a second concurrent accept.

        await realtime.ToUser(bid.DriverId, RideEvents.BidAccepted, RideMapping.ToDto(ride, false));
        await realtime.ToUsers(losers.Select(l => l.DriverId), RideEvents.BidDeclined, new { rideId = ride.Id });
        await CloseRequestForOthersAsync(ride, bid.DriverId, ct);
        await realtime.ToAdmins(RideEvents.Updated, RideMapping.ToDto(ride, false));
        return RideMapping.ToDto(ride, true);
    }

    public async Task DeclineBidAsync(Guid passengerId, Guid bidId, CancellationToken ct)
    {
        var bid = await db.Bids.FirstOrDefaultAsync(b => b.Id == bidId, ct) ?? throw AppException.NotFound("Offer not found.");
        await LoadForAsync(passengerId, UserRole.Passenger, bid.RideId, ct);
        if (bid.Status != BidStatus.Pending) return;
        bid.Status = BidStatus.Declined;
        await db.SaveChangesAsync(ct);
        await realtime.ToUser(bid.DriverId, RideEvents.BidDeclined, new { rideId = bid.RideId });
    }

    public async Task<RideDto> CancelAsync(Guid userId, UserRole role, Guid rideId, string? reason, CancellationToken ct)
    {
        var ride = await LoadForAsync(userId, role, rideId, ct);
        if (ride.Status is RideStatus.InProgress or RideStatus.AwaitingPayment or RideStatus.Completed or RideStatus.Cancelled)
            throw AppException.Conflict(ride.Status == RideStatus.Cancelled ? "This ride is already cancelled." : "A ride cannot be cancelled once the trip has started.");

        ride.Status = RideStatus.Cancelled;
        ride.CancelledAt = DateTime.UtcNow;
        ride.CancelledBy = role;
        ride.CancelReason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim();
        var pending = await db.Bids.Where(b => b.RideId == ride.Id && b.Status == BidStatus.Pending).ToListAsync(ct);
        pending.ForEach(b => b.Status = BidStatus.Expired);
        await db.SaveChangesAsync(ct);

        await NotifyPartiesAsync(ride);
        await CloseRequestForOthersAsync(ride, null, ct);
        return RideMapping.ToDto(ride, role == UserRole.Passenger);
    }

    /// <summary>Passenger pays a ride that the driver has ended. Cash is confirmed by the driver instead.</summary>
    public async Task<RideDto> PayAsync(Guid passengerId, Guid rideId, PayRideRequest r, CancellationToken ct)
    {
        var ride = await LoadForAsync(passengerId, UserRole.Passenger, rideId, ct);
        if (ride.Status != RideStatus.AwaitingPayment) throw AppException.Conflict("This ride is not waiting for payment.");
        if (r.Tip is < 0 or > 1000) throw AppException.BadRequest("Tip must be between Le 0 and Le 1,000.");
        ride.Tip = r.Tip is > 0 ? r.Tip : null;

        switch (r.Method)
        {
            case PaymentMethod.Wallet:
                WalletService.Settle(db, ride, ride.Passenger, ride.Driver!, PaymentMethod.Wallet);
                break;
            case PaymentMethod.Cash:
                ride.PaymentMethod = PaymentMethod.Cash; // the driver confirms receipt
                break;
            default:
                throw AppException.BadRequest("Orange Money and card payments are coming soon. Pay with wallet or cash.");
        }
        await db.SaveChangesAsync(ct);
        await NotifyPartiesAsync(ride);
        return RideMapping.ToDto(ride, true);
    }

    public async Task RateAsync(Guid userId, UserRole role, Guid rideId, RateRequest r, CancellationToken ct)
    {
        if (r.Stars is < 1 or > 5) throw AppException.BadRequest("Choose between 1 and 5 stars.");
        var ride = await LoadForAsync(userId, role, rideId, ct);
        if (ride.Status != RideStatus.Completed) throw AppException.Conflict("You can rate a trip once it is completed.");
        if (await db.Reviews.AnyAsync(x => x.RideId == rideId && x.FromUserId == userId, ct))
            throw AppException.Conflict("You have already rated this trip.");

        var target = role == UserRole.Passenger ? ride.Driver! : ride.Passenger;
        db.Reviews.Add(new Review { RideId = rideId, FromUserId = userId, ToUserId = target.Id, Stars = r.Stars, Comment = r.Comment?.Trim() });
        target.Rating = Math.Round((target.Rating * target.RatingCount + r.Stars) / (target.RatingCount + 1), 2);
        target.RatingCount++;

        // A tip after a wallet-paid ride is moved straight from the passenger's wallet.
        if (role == UserRole.Passenger && r.Tip is > 0 and <= 1000 && ride.PaymentMethod == PaymentMethod.Wallet && ride.Tip is null)
        {
            if (ride.Passenger.WalletBalance < r.Tip) throw AppException.BadRequest("Your wallet balance does not cover this tip.");
            ride.Tip = r.Tip;
            WalletService.Post(db, ride.Passenger, WalletTxType.Tip, -r.Tip.Value, $"Tip for {ride.Driver!.FullName}", ride.Id);
            WalletService.Post(db, ride.Driver!, WalletTxType.Tip, r.Tip.Value, $"Tip from {ride.Passenger.FullName}", ride.Id);
        }
        await db.SaveChangesAsync(ct);
    }

    public async Task SosAsync(Guid userId, UserRole role, Guid rideId, SosRequest r, CancellationToken ct)
    {
        var ride = await LoadForAsync(userId, role, rideId, ct);
        var raisedBy = role == UserRole.Passenger ? ride.Passenger : ride.Driver!;
        var alert = new SosAlert
        {
            RideId = ride.Id, Ride = ride, RaisedById = userId, RaisedBy = raisedBy,
            Lat = r.Lat ?? ride.Driver?.DriverProfile?.Lat, Lng = r.Lng ?? ride.Driver?.DriverProfile?.Lng,
            Message = r.Message?.Trim()
        };
        db.SosAlerts.Add(alert);
        await db.SaveChangesAsync(ct);
        await realtime.ToAdmins(RideEvents.Sos, new
        {
            alert.Id, alert.RideId, rideCode = ride.Code, alert.Lat, alert.Lng, alert.Message, alert.CreatedAt,
            raisedBy = new { raisedBy.Id, raisedBy.FullName, raisedBy.Phone, role },
            emergencyContact = raisedBy.EmergencyContact
        });
    }

    public async Task<List<MessageDto>> MessagesAsync(Guid userId, UserRole role, Guid rideId, CancellationToken ct)
    {
        await LoadForAsync(userId, role, rideId, ct);
        return await db.RideMessages.Where(m => m.RideId == rideId).OrderBy(m => m.CreatedAt)
            .Select(m => new MessageDto(m.Id, m.RideId, m.SenderId, m.Text, m.CreatedAt)).ToListAsync(ct);
    }

    public async Task<MessageDto> SendMessageAsync(Guid userId, UserRole role, Guid rideId, string text, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(text)) throw AppException.BadRequest("Type a message.");
        var ride = await LoadForAsync(userId, role, rideId, ct);
        if (ride.DriverId == null || ride.Status is RideStatus.Completed or RideStatus.Cancelled)
            throw AppException.Conflict("Chat is available while a driver is assigned.");
        var m = new RideMessage { RideId = rideId, SenderId = userId, Text = text.Trim()[..Math.Min(500, text.Trim().Length)] };
        db.RideMessages.Add(m);
        await db.SaveChangesAsync(ct);
        var dto = new MessageDto(m.Id, m.RideId, m.SenderId, m.Text, m.CreatedAt);
        await realtime.ToUsers([ride.PassengerId, ride.DriverId!.Value], RideEvents.Message, dto);
        return dto;
    }

    // ---------- Shared helpers ----------

    private IQueryable<Ride> Rides() =>
        db.Rides.Include(r => r.Passenger).Include(r => r.Service)
            .Include(r => r.Driver).ThenInclude(d => d!.DriverProfile);

    private async Task<Ride> LoadForAsync(Guid userId, UserRole role, Guid rideId, CancellationToken ct)
    {
        var ride = await Rides().FirstOrDefaultAsync(r => r.Id == rideId, ct) ?? throw AppException.NotFound("Ride not found.");
        var allowed = role switch
        {
            UserRole.Passenger => ride.PassengerId == userId,
            UserRole.Driver => ride.DriverId == userId,
            _ => true
        };
        if (!allowed) throw AppException.NotFound("Ride not found.");
        return ride;
    }

    private async Task NotifyPartiesAsync(Ride ride)
    {
        await realtime.ToUser(ride.PassengerId, RideEvents.Updated, RideMapping.ToDto(ride, true));
        if (ride.DriverId is { } d) await realtime.ToUser(d, RideEvents.Updated, RideMapping.ToDto(ride, false));
        await realtime.ToAdmins(RideEvents.Updated, RideMapping.ToDto(ride, false));
    }

    /// <summary>Removes the request card from drivers who bid but were not chosen, or who could still see it.</summary>
    private async Task CloseRequestForOthersAsync(Ride ride, Guid? exceptDriverId, CancellationToken ct)
    {
        var drivers = (await OnlineDriversAsync(ride.ServiceId, ct)).Select(d => d.UserId).Where(id => id != exceptDriverId);
        await realtime.ToUsers(drivers, RideEvents.RequestClosed, new { rideId = ride.Id });
    }

    private async Task<List<DriverProfile>> OnlineDriversAsync(Guid? serviceId, CancellationToken ct)
    {
        var cutoff = DateTime.UtcNow - DriverStaleAfter;
        var busy = db.Rides.Where(r => r.DriverId != null && ActiveStatuses.Contains(r.Status) && r.Status != RideStatus.Searching)
            .Select(r => r.DriverId!.Value);
        return await db.DriverProfiles
            .Where(d => d.IsOnline && d.Status == DriverStatus.Approved && d.Lat != null && d.Lng != null && d.LastSeenAt >= cutoff)
            .Where(d => serviceId == null || d.ServiceId == serviceId)
            .Where(d => !busy.Contains(d.UserId))
            .ToListAsync(ct);
    }

    private async Task<Coupon?> FindCouponAsync(string? code, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(code)) return null;
        var c = await db.Coupons.FirstOrDefaultAsync(x => x.Code == code.Trim().ToUpper() && x.IsActive, ct);
        if (c == null || (c.ExpiresAt != null && c.ExpiresAt < DateTime.UtcNow) || (c.UsageLimit != null && c.TimesUsed >= c.UsageLimit))
            throw AppException.BadRequest("This promo code is not valid.");
        return c;
    }

    private static int EtaMinutes(double km) => Math.Max(1, (int)Math.Ceiling(km * Geo.RoadFactor / Geo.AverageKmh * 60));

    private static RideRequestDto ToRequestDto(Ride r, double driverLat, double driverLng, decimal? myBid) => new(
        r.Id, r.Code, r.Service.Name,
        new PlacePoint(r.PickupAddress, r.PickupLat, r.PickupLng), new PlacePoint(r.DropoffAddress, r.DropoffLat, r.DropoffLng),
        r.DistanceKm, r.DurationMinutes, Math.Round(Geo.HaversineKm(driverLat, driverLng, r.PickupLat, r.PickupLng) * Geo.RoadFactor, 1),
        r.OfferedFare, r.EstimatedFare, r.PaymentMethod, r.Passenger.FullName, r.Passenger.PhotoUrl, r.Passenger.Rating,
        r.CreatedAt, myBid);
}
