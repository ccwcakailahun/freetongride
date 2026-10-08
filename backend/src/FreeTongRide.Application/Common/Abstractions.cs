using FreeTongRide.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Common;

public interface IAppDbContext
{
    DbSet<User> Users { get; }
    DbSet<SavedPlace> SavedPlaces { get; }
    DbSet<OtpCode> OtpCodes { get; }
    DbSet<DriverProfile> DriverProfiles { get; }
    DbSet<DriverDocument> DriverDocuments { get; }
    DbSet<Service> Services { get; }
    DbSet<Ride> Rides { get; }
    DbSet<Bid> Bids { get; }
    DbSet<RideMessage> RideMessages { get; }
    DbSet<Review> Reviews { get; }
    DbSet<SosAlert> SosAlerts { get; }
    DbSet<WalletTransaction> WalletTransactions { get; }
    DbSet<Withdrawal> Withdrawals { get; }
    DbSet<Coupon> Coupons { get; }
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}

public interface IPasswordService
{
    string Hash(User user, string password);
    bool Verify(User user, string password);
}

public interface ITokenService
{
    AuthTokens Issue(User user);
}

public record AuthTokens(string AccessToken, DateTime ExpiresAt);

public interface ISmsSender
{
    Task SendAsync(string phone, string message, CancellationToken ct = default);
}

/// <summary>Pushes live events to the apps and the admin panel (SignalR in the API).</summary>
public interface IRealtime
{
    Task ToUser(Guid userId, string evt, object payload);
    Task ToUsers(IEnumerable<Guid> userIds, string evt, object payload);
    Task ToAdmins(string evt, object payload);
}

public class AppException(int status, string message) : Exception(message)
{
    public int Status { get; } = status;

    public static AppException BadRequest(string m) => new(400, m);
    public static AppException Unauthorized(string m) => new(401, m);
    public static AppException Forbidden(string m) => new(403, m);
    public static AppException NotFound(string m) => new(404, m);
    public static AppException Conflict(string m) => new(409, m);
}

public record PagedResult<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);
