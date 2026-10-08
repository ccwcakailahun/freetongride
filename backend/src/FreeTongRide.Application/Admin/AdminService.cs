using FreeTongRide.Application.Common;
using FreeTongRide.Application.Drivers;
using FreeTongRide.Application.Rides;
using FreeTongRide.Application.Wallet;
using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Admin;

public record DailyPoint(DateOnly Day, int Rides, decimal Gmv, decimal Commission);
public record DashboardDto(
    int RidesToday, int CompletedToday, int CancelledToday, int ActiveRides, int SearchingRides,
    decimal GmvToday, decimal CommissionToday, int DriversOnline, int DriversPendingReview,
    int PassengersTotal, int DriversTotal, int NewPassengersToday, int OpenSos, int PendingWithdrawals,
    decimal PendingWithdrawalAmount, IReadOnlyList<DailyPoint> Last14Days, IReadOnlyList<ServiceSplit> ServiceSplitToday);
public record ServiceSplit(string Service, int Rides);

public record AdminDriverRow(
    Guid Id, string FullName, string Phone, string? Email, string? PhotoUrl, DriverStatus Status, string? ServiceName,
    string Vehicle, string? PlateNumber, bool IsOnline, double Rating, int RatingCount, int CompletedTrips,
    decimal WalletBalance, bool IsActive, DateTime CreatedAt, DateTime? LastSeenAt, bool PhoneVerified);
public record AdminDriverDetail(AdminDriverRow Driver, DriverProfileDto Profile, IReadOnlyList<RideDto> RecentRides);
public record AdminPassengerRow(Guid Id, string FullName, string Phone, string? Email, string? PhotoUrl, bool PhoneVerified, bool IsActive, double Rating, decimal WalletBalance, int Rides, DateTime CreatedAt, DateTime? LastLoginAt);
public record AdminRideDetail(RideDto Ride, IReadOnlyList<BidDto> Bids, IReadOnlyList<MessageDto> Messages, IReadOnlyList<SosDto> Sos);
public record SosDto(Guid Id, Guid RideId, string RideCode, SosStatus Status, double? Lat, double? Lng, string? Message, string RaisedByName, string RaisedByPhone, UserRole RaisedByRole, string? EmergencyContact, DateTime CreatedAt, DateTime? ResolvedAt, string? ResolutionNote);
public record AdminWithdrawalRow(Guid Id, Guid DriverId, string DriverName, string DriverPhone, decimal Amount, string Method, string AccountNumber, WithdrawalStatus Status, string? AdminNote, DateTime CreatedAt, DateTime? ProcessedAt);
public record AdminTxRow(Guid Id, string UserName, UserRole Role, WalletTxType Type, decimal Amount, decimal BalanceAfter, string Description, string? Reference, DateTime CreatedAt);
public record LiveDriver(Guid Id, string FullName, string? ServiceName, string? PlateNumber, double Lat, double Lng, double? Heading, bool OnTrip, Guid? RideId, DateTime? LastSeenAt);
public record LiveMapDto(IReadOnlyList<LiveDriver> Drivers, IReadOnlyList<RideDto> ActiveRides);
public record ReviewDecision(bool Approve, string? Reason);
public record NoteRequest(string? Note);
public record SaveServiceRequest(string Name, string Description, int Seats, decimal BaseFare, decimal PerKm, decimal PerMinute, decimal MinimumFare, decimal CommissionPercent, bool IsActive, int SortOrder);

public class AdminService(IAppDbContext db, IRealtime realtime)
{
    public async Task<DashboardDto> DashboardAsync(CancellationToken ct)
    {
        var today = DateTime.UtcNow.Date;
        var from = today.AddDays(-13);
        var recent = await db.Rides.Where(r => r.CreatedAt >= from)
            .Select(r => new { r.CreatedAt, r.Status, Fare = (r.AgreedFare ?? r.OfferedFare) - (r.Discount ?? 0), Commission = r.Commission ?? 0, Service = r.Service.Name })
            .ToListAsync(ct);
        var todays = recent.Where(r => r.CreatedAt >= today).ToList();
        var completedToday = todays.Where(r => r.Status == RideStatus.Completed).ToList();
        var cutoff = DateTime.UtcNow - RideService.DriverStaleAfter;
        var pendingW = db.Withdrawals.Where(w => w.Status == WithdrawalStatus.Pending);

        var days = Enumerable.Range(0, 14).Select(i => from.AddDays(i)).Select(d =>
        {
            var dayRides = recent.Where(r => r.CreatedAt.Date == d).ToList();
            var done = dayRides.Where(r => r.Status == RideStatus.Completed).ToList();
            return new DailyPoint(DateOnly.FromDateTime(d), dayRides.Count, done.Sum(r => r.Fare), done.Sum(r => r.Commission));
        }).ToList();

        return new DashboardDto(
            todays.Count, completedToday.Count, todays.Count(r => r.Status == RideStatus.Cancelled),
            await db.Rides.CountAsync(r => RideService.ActiveStatuses.Contains(r.Status) && r.Status != RideStatus.Searching, ct),
            await db.Rides.CountAsync(r => r.Status == RideStatus.Searching, ct),
            completedToday.Sum(r => r.Fare), completedToday.Sum(r => r.Commission),
            await db.DriverProfiles.CountAsync(d => d.IsOnline && d.LastSeenAt >= cutoff, ct),
            await db.DriverProfiles.CountAsync(d => d.Status == DriverStatus.UnderReview, ct),
            await db.Users.CountAsync(u => u.Role == UserRole.Passenger, ct),
            await db.Users.CountAsync(u => u.Role == UserRole.Driver, ct),
            await db.Users.CountAsync(u => u.Role == UserRole.Passenger && u.CreatedAt >= today, ct),
            await db.SosAlerts.CountAsync(s => s.Status != SosStatus.Resolved, ct),
            await pendingW.CountAsync(ct),
            await pendingW.SumAsync(w => (decimal?)w.Amount, ct) ?? 0,
            days,
            todays.GroupBy(r => r.Service).Select(g => new ServiceSplit(g.Key, g.Count())).OrderByDescending(s => s.Rides).ToList());
    }

    // ---------- Rides ----------

    public async Task<PagedResult<RideDto>> RidesAsync(RideStatus? status, string? search, DateTime? from, DateTime? to, int page, int pageSize, CancellationToken ct)
    {
        var q = RideQuery();
        if (status != null) q = q.Where(r => r.Status == status);
        // Dates from the query string have no kind; the database stores UTC.
        if (from != null) { var f = DateTime.SpecifyKind(from.Value.Date, DateTimeKind.Utc); q = q.Where(r => r.CreatedAt >= f); }
        if (to != null) { var t = DateTime.SpecifyKind(to.Value.Date.AddDays(1), DateTimeKind.Utc); q = q.Where(r => r.CreatedAt < t); }
        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            q = q.Where(r => r.Code.ToLower().Contains(s) || r.Passenger.FullName.ToLower().Contains(s) || r.Passenger.Phone.ToLower().Contains(s) ||
                             (r.Driver != null && (r.Driver.FullName.ToLower().Contains(s) || r.Driver.Phone.ToLower().Contains(s))) ||
                             r.PickupAddress.ToLower().Contains(s) || r.DropoffAddress.ToLower().Contains(s));
        }
        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(r => r.CreatedAt).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PagedResult<RideDto>(items.Select(r => RideMapping.ToDto(r, false)).ToList(), total, page, pageSize);
    }

    public async Task<AdminRideDetail> RideAsync(Guid id, CancellationToken ct)
    {
        var ride = await RideQuery().FirstOrDefaultAsync(r => r.Id == id, ct) ?? throw AppException.NotFound("Ride not found.");
        var bids = await db.Bids.Include(b => b.Driver).ThenInclude(d => d.DriverProfile).Where(b => b.RideId == id).OrderBy(b => b.CreatedAt).ToListAsync(ct);
        var messages = await db.RideMessages.Where(m => m.RideId == id).OrderBy(m => m.CreatedAt)
            .Select(m => new MessageDto(m.Id, m.RideId, m.SenderId, m.Text, m.CreatedAt)).ToListAsync(ct);
        var sos = await SosQuery().Where(s => s.RideId == id).ToListAsync(ct);
        return new AdminRideDetail(RideMapping.ToDto(ride, false), bids.Select(RideMapping.ToDto).ToList(), messages, sos.Select(ToDto).ToList());
    }

    public async Task<RideDto> CancelRideAsync(Guid id, string? reason, CancellationToken ct)
    {
        var ride = await RideQuery().FirstOrDefaultAsync(r => r.Id == id, ct) ?? throw AppException.NotFound("Ride not found.");
        if (ride.Status is RideStatus.Completed or RideStatus.Cancelled) throw AppException.Conflict("This ride is already closed.");
        ride.Status = RideStatus.Cancelled;
        ride.CancelledAt = DateTime.UtcNow;
        ride.CancelledBy = UserRole.Admin;
        ride.CancelReason = reason ?? "Cancelled by FreeTongRide support";
        await db.SaveChangesAsync(ct);
        await realtime.ToUser(ride.PassengerId, RideEvents.Updated, RideMapping.ToDto(ride, true));
        if (ride.DriverId is { } d) await realtime.ToUser(d, RideEvents.Updated, RideMapping.ToDto(ride, false));
        await realtime.ToAdmins(RideEvents.Updated, RideMapping.ToDto(ride, false));
        return RideMapping.ToDto(ride, false);
    }

    public async Task<LiveMapDto> LiveMapAsync(CancellationToken ct)
    {
        var cutoff = DateTime.UtcNow - RideService.DriverStaleAfter;
        var active = await RideQuery().Where(r => RideService.ActiveStatuses.Contains(r.Status)).ToListAsync(ct);
        var onTrip = active.Where(r => r.DriverId != null).ToDictionary(r => r.DriverId!.Value, r => r.Id);
        var drivers = await db.DriverProfiles.Include(d => d.User).Include(d => d.Service)
            .Where(d => d.IsOnline && d.LastSeenAt >= cutoff && d.Lat != null).ToListAsync(ct);
        return new LiveMapDto(
            drivers.Select(d => new LiveDriver(d.UserId, d.User.FullName, d.Service?.Name, d.PlateNumber, d.Lat!.Value, d.Lng!.Value, d.Heading,
                onTrip.ContainsKey(d.UserId), onTrip.TryGetValue(d.UserId, out var rid) ? rid : null, d.LastSeenAt)).ToList(),
            active.Select(r => RideMapping.ToDto(r, false)).ToList());
    }

    // ---------- Drivers ----------

    public async Task<PagedResult<AdminDriverRow>> DriversAsync(DriverStatus? status, bool? online, string? search, int page, int pageSize, CancellationToken ct)
    {
        var q = db.DriverProfiles.Include(d => d.User).Include(d => d.Service).AsQueryable();
        if (status != null) q = q.Where(d => d.Status == status);
        if (online != null) q = q.Where(d => d.IsOnline == online);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            q = q.Where(d => d.User.FullName.ToLower().Contains(s) || d.User.Phone.ToLower().Contains(s) || (d.PlateNumber != null && d.PlateNumber.ToLower().Contains(s)));
        }
        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(d => d.Status == DriverStatus.UnderReview).ThenByDescending(d => d.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PagedResult<AdminDriverRow>(items.Select(ToRow).ToList(), total, page, pageSize);
    }

    public async Task<AdminDriverDetail> DriverAsync(Guid userId, CancellationToken ct)
    {
        var p = await DriverQuery().FirstOrDefaultAsync(d => d.UserId == userId, ct) ?? throw AppException.NotFound("Driver not found.");
        var rides = await RideQuery().Where(r => r.DriverId == userId).OrderByDescending(r => r.CreatedAt).Take(20).ToListAsync(ct);
        return new AdminDriverDetail(ToRow(p), DriverOnboardingService.ToDto(p), rides.Select(r => RideMapping.ToDto(r, false)).ToList());
    }

    public async Task<AdminDriverDetail> ReviewDriverAsync(Guid userId, ReviewDecision d, CancellationToken ct)
    {
        var p = await DriverQuery().FirstOrDefaultAsync(x => x.UserId == userId, ct) ?? throw AppException.NotFound("Driver not found.");
        if (!d.Approve && string.IsNullOrWhiteSpace(d.Reason)) throw AppException.BadRequest("Tell the driver why they were rejected.");
        p.Status = d.Approve ? DriverStatus.Approved : DriverStatus.Rejected;
        p.RejectReason = d.Approve ? null : d.Reason!.Trim();
        p.ApprovedAt = d.Approve ? DateTime.UtcNow : null;
        foreach (var doc in p.Documents) doc.Approved = d.Approve;
        if (!d.Approve) p.IsOnline = false;
        await db.SaveChangesAsync(ct);
        await realtime.ToUser(userId, "driver.reviewed", new { status = p.Status, reason = p.RejectReason });
        return await DriverAsync(userId, ct);
    }

    public async Task SetDriverSuspendedAsync(Guid userId, bool suspended, CancellationToken ct)
    {
        var p = await DriverQuery().FirstOrDefaultAsync(x => x.UserId == userId, ct) ?? throw AppException.NotFound("Driver not found.");
        p.Status = suspended ? DriverStatus.Suspended : DriverStatus.Approved;
        if (suspended) p.IsOnline = false;
        await db.SaveChangesAsync(ct);
        await realtime.ToUser(userId, "driver.reviewed", new { status = p.Status });
    }

    // ---------- Passengers ----------

    public async Task<PagedResult<AdminPassengerRow>> PassengersAsync(string? search, int page, int pageSize, CancellationToken ct)
    {
        var q = db.Users.Where(u => u.Role == UserRole.Passenger);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            q = q.Where(u => u.FullName.ToLower().Contains(s) || u.Phone.ToLower().Contains(s) || (u.Email != null && u.Email.ToLower().Contains(s)));
        }
        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(u => u.CreatedAt).Skip((page - 1) * pageSize).Take(pageSize)
            .Select(u => new AdminPassengerRow(u.Id, u.FullName, u.Phone, u.Email, u.PhotoUrl, u.PhoneVerified, u.IsActive, u.Rating, u.WalletBalance,
                db.Rides.Count(r => r.PassengerId == u.Id), u.CreatedAt, u.LastLoginAt))
            .ToListAsync(ct);
        return new PagedResult<AdminPassengerRow>(items, total, page, pageSize);
    }

    /// <summary>Marks a phone as verified by hand, for people who could not receive the SMS code.</summary>
    public async Task VerifyPhoneAsync(Guid userId, CancellationToken ct)
    {
        var u = await db.Users.FirstOrDefaultAsync(x => x.Id == userId, ct) ?? throw AppException.NotFound("User not found.");
        u.PhoneVerified = true;
        await db.SaveChangesAsync(ct);
    }

    public async Task SetUserActiveAsync(Guid userId, bool active, CancellationToken ct)
    {
        var u = await db.Users.FirstOrDefaultAsync(x => x.Id == userId, ct) ?? throw AppException.NotFound("User not found.");
        if (u.Role == UserRole.Admin) throw AppException.Forbidden("Admin accounts cannot be suspended here.");
        u.IsActive = active;
        await db.SaveChangesAsync(ct);
    }

    // ---------- SOS ----------

    public async Task<List<SosDto>> SosAsync(bool openOnly, CancellationToken ct)
    {
        var q = SosQuery();
        if (openOnly) q = q.Where(s => s.Status != SosStatus.Resolved);
        return (await q.OrderByDescending(s => s.CreatedAt).Take(100).ToListAsync(ct)).Select(ToDto).ToList();
    }

    public async Task<SosDto> UpdateSosAsync(Guid id, Guid adminId, SosStatus status, string? note, CancellationToken ct)
    {
        var s = await SosQuery().FirstOrDefaultAsync(x => x.Id == id, ct) ?? throw AppException.NotFound("Alert not found.");
        s.Status = status;
        s.HandledById = adminId;
        if (status == SosStatus.Resolved)
        {
            s.ResolvedAt = DateTime.UtcNow;
            s.ResolutionNote = note?.Trim();
        }
        await db.SaveChangesAsync(ct);
        var dto = ToDto(s);
        await realtime.ToAdmins(RideEvents.SosUpdated, dto);
        return dto;
    }

    // ---------- Money ----------

    public async Task<PagedResult<AdminWithdrawalRow>> WithdrawalsAsync(WithdrawalStatus? status, int page, int pageSize, CancellationToken ct)
    {
        var q = db.Withdrawals.Include(w => w.Driver).AsQueryable();
        if (status != null) q = q.Where(w => w.Status == status);
        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(w => w.CreatedAt).Skip((page - 1) * pageSize).Take(pageSize)
            .Select(w => new AdminWithdrawalRow(w.Id, w.DriverId, w.Driver.FullName, w.Driver.Phone, w.Amount, w.Method, w.AccountNumber, w.Status, w.AdminNote, w.CreatedAt, w.ProcessedAt))
            .ToListAsync(ct);
        return new PagedResult<AdminWithdrawalRow>(items, total, page, pageSize);
    }

    public async Task ProcessWithdrawalAsync(Guid id, ReviewDecision d, CancellationToken ct)
    {
        var w = await db.Withdrawals.Include(x => x.Driver).FirstOrDefaultAsync(x => x.Id == id, ct) ?? throw AppException.NotFound("Withdrawal not found.");
        if (w.Status != WithdrawalStatus.Pending) throw AppException.Conflict("This withdrawal has already been processed.");
        w.Status = d.Approve ? WithdrawalStatus.Approved : WithdrawalStatus.Rejected;
        w.AdminNote = d.Reason?.Trim();
        w.ProcessedAt = DateTime.UtcNow;
        if (!d.Approve)
            WalletService.Post(db, w.Driver, WalletTxType.Refund, w.Amount, "Withdrawal rejected, money returned", reference: w.Id.ToString());
        await db.SaveChangesAsync(ct);
        await realtime.ToUser(w.DriverId, "withdrawal.updated", WalletService.ToDto(w));
    }

    public async Task<PagedResult<AdminTxRow>> TransactionsAsync(WalletTxType? type, string? search, int page, int pageSize, CancellationToken ct)
    {
        var q = db.WalletTransactions.Include(t => t.User).AsQueryable();
        if (type != null) q = q.Where(t => t.Type == type);
        var q2 = (search ?? "").Trim().ToLower();
        if (q2.Length > 0) q = q.Where(t => t.User.FullName.ToLower().Contains(q2) || t.User.Phone.ToLower().Contains(q2) || t.Description.ToLower().Contains(q2));
        var total = await q.CountAsync(ct);
        var items = await q.OrderByDescending(t => t.CreatedAt).Skip((page - 1) * pageSize).Take(pageSize)
            .Select(t => new AdminTxRow(t.Id, t.User.FullName, t.User.Role, t.Type, t.Amount, t.BalanceAfter, t.Description, t.Reference, t.CreatedAt))
            .ToListAsync(ct);
        return new PagedResult<AdminTxRow>(items, total, page, pageSize);
    }

    // ---------- Services & fares ----------

    public async Task<List<ServiceDto>> ServicesAsync(CancellationToken ct) =>
        (await db.Services.OrderBy(s => s.SortOrder).ToListAsync(ct)).Select(DriverOnboardingService.ToDto).ToList();

    public async Task<ServiceDto> SaveServiceAsync(Guid? id, SaveServiceRequest r, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(r.Name)) throw AppException.BadRequest("Name is required.");
        if (r.BaseFare < 0 || r.PerKm < 0 || r.PerMinute < 0 || r.MinimumFare < 0) throw AppException.BadRequest("Fares cannot be negative.");
        if (r.CommissionPercent is < 0 or > 50) throw AppException.BadRequest("Commission must be between 0% and 50%.");
        Service s;
        if (id == null) { s = new Service(); db.Services.Add(s); }
        else s = await db.Services.FirstOrDefaultAsync(x => x.Id == id, ct) ?? throw AppException.NotFound("Ride type not found.");
        s.Name = r.Name.Trim(); s.Description = r.Description.Trim(); s.Seats = r.Seats;
        s.BaseFare = r.BaseFare; s.PerKm = r.PerKm; s.PerMinute = r.PerMinute; s.MinimumFare = r.MinimumFare;
        s.CommissionPercent = r.CommissionPercent; s.IsActive = r.IsActive; s.SortOrder = r.SortOrder;
        await db.SaveChangesAsync(ct);
        return DriverOnboardingService.ToDto(s);
    }

    // ---------- helpers ----------

    private IQueryable<Ride> RideQuery() =>
        db.Rides.Include(r => r.Passenger).Include(r => r.Service).Include(r => r.Driver).ThenInclude(d => d!.DriverProfile);

    private IQueryable<DriverProfile> DriverQuery() =>
        db.DriverProfiles.Include(d => d.User).Include(d => d.Service).Include(d => d.Documents);

    private IQueryable<SosAlert> SosQuery() => db.SosAlerts.Include(s => s.Ride).Include(s => s.RaisedBy);

    private static AdminDriverRow ToRow(DriverProfile d) => new(
        d.UserId, d.User.FullName, d.User.Phone, d.User.Email, d.User.PhotoUrl, d.Status, d.Service?.Name, d.VehicleSummary,
        d.PlateNumber, d.IsOnline, d.User.Rating, d.User.RatingCount, d.CompletedTrips, d.User.WalletBalance, d.User.IsActive,
        d.CreatedAt, d.LastSeenAt, d.User.PhoneVerified);

    private static SosDto ToDto(SosAlert s) => new(
        s.Id, s.RideId, s.Ride.Code, s.Status, s.Lat, s.Lng, s.Message, s.RaisedBy.FullName, s.RaisedBy.Phone, s.RaisedBy.Role,
        s.RaisedBy.EmergencyContact, s.CreatedAt, s.ResolvedAt, s.ResolutionNote);
}
