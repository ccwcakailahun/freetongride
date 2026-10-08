using FreeTongRide.Application.Common;
using FreeTongRide.Application.Fares;
using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Wallet;

public record WalletTxDto(Guid Id, WalletTxType Type, decimal Amount, decimal BalanceAfter, string Description, Guid? RideId, string? Reference, DateTime CreatedAt);
public record WalletSummaryDto(decimal Balance, int Points, IReadOnlyList<WalletTxDto> Recent);
public record TopUpRequest(decimal Amount, PaymentMethod Method, string? PayerPhone);
public record WithdrawRequest(decimal Amount, string Method, string AccountNumber);
public record WithdrawalDto(Guid Id, decimal Amount, string Method, string AccountNumber, WithdrawalStatus Status, string? AdminNote, DateTime CreatedAt, DateTime? ProcessedAt);
public record EarningsDto(decimal Balance, decimal Today, decimal ThisWeek, int TripsToday, int TripsThisWeek, decimal CommissionThisWeek, double Rating, IReadOnlyList<WalletTxDto> Recent);

public class WalletService(IAppDbContext db)
{
    public const decimal MinimumWithdrawal = 50m;

    /// <summary>Changes the balance and records the ledger line. Caller saves.</summary>
    public static WalletTransaction Post(IAppDbContext db, User user, WalletTxType type, decimal amount, string description, Guid? rideId = null, string? reference = null)
    {
        user.WalletBalance += amount;
        var tx = new WalletTransaction
        {
            UserId = user.Id, Type = type, Amount = amount, BalanceAfter = user.WalletBalance,
            Description = description, RideId = rideId, Reference = reference
        };
        db.WalletTransactions.Add(tx);
        return tx;
    }

    /// <summary>
    /// Closes a ride's money. Cash: the driver already holds the fare, so the platform's commission is
    /// taken from the driver's wallet. Wallet: the passenger is debited and the driver credited net of commission.
    /// </summary>
    public static void Settle(IAppDbContext db, Ride ride, User passenger, User driver, PaymentMethod method)
    {
        var fare = ride.FareDue;
        var tip = ride.Tip ?? 0;
        var commission = FareCalculator.Commission(fare, ride.Service.CommissionPercent);
        ride.Commission = commission;
        ride.PaymentMethod = method;

        if (method == PaymentMethod.Cash)
        {
            Post(db, driver, WalletTxType.Commission, -commission, $"Commission for ride {ride.Code} (cash trip)", ride.Id);
        }
        else
        {
            var total = fare + tip;
            if (passenger.WalletBalance < total)
                throw AppException.BadRequest($"Wallet balance is too low. Add Le {total - passenger.WalletBalance:N0} or pay with cash.");
            Post(db, passenger, WalletTxType.RidePayment, -fare, $"Ride to {ride.DropoffAddress}", ride.Id);
            Post(db, driver, WalletTxType.RideEarning, fare - commission, $"Earning for ride {ride.Code}", ride.Id);
            if (tip > 0)
            {
                Post(db, passenger, WalletTxType.Tip, -tip, $"Tip for {driver.FullName}", ride.Id);
                Post(db, driver, WalletTxType.Tip, tip, $"Tip from {passenger.FullName}", ride.Id);
            }
        }

        ride.PaymentStatus = PaymentStatus.Paid;
        ride.Status = RideStatus.Completed;
        ride.CompletedAt = DateTime.UtcNow;
        if (driver.DriverProfile != null) driver.DriverProfile.CompletedTrips++;
        // 1 point per Le 10 spent.
        passenger.Points += (int)Math.Floor(fare / 10m);
    }

    public async Task<WalletSummaryDto> SummaryAsync(Guid userId, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        var recent = await HistoryQuery(userId).Take(20).ToListAsync(ct);
        return new WalletSummaryDto(user.WalletBalance, user.Points, recent);
    }

    public async Task<PagedResult<WalletTxDto>> HistoryAsync(Guid userId, int page, int pageSize, CancellationToken ct)
    {
        var q = HistoryQuery(userId);
        return new PagedResult<WalletTxDto>(await q.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct),
            await q.CountAsync(ct), page, pageSize);
    }

    /// <summary>
    /// Development top-up. Orange Money and card top-ups will go through a payment gateway that
    /// credits the wallet from its callback; until that is connected the API only allows this in Development.
    /// </summary>
    public async Task<WalletSummaryDto> DevTopUpAsync(Guid userId, TopUpRequest r, CancellationToken ct)
    {
        if (r.Amount < 10 || r.Amount > 10_000) throw AppException.BadRequest("Top-up must be between Le 10 and Le 10,000.");
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        Post(db, user, WalletTxType.TopUp, r.Amount, $"Added funds ({Label(r.Method)})", reference: "DEV-" + Codes.Numeric(8));
        await db.SaveChangesAsync(ct);
        return await SummaryAsync(userId, ct);
    }

    public async Task<EarningsDto> EarningsAsync(Guid driverId, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == driverId, ct);
        var today = DateTime.UtcNow.Date;
        var week = today.AddDays(-(((int)today.DayOfWeek + 6) % 7)); // Monday
        var rides = db.Rides.Where(r => r.DriverId == driverId && r.Status == RideStatus.Completed);
        var weekRides = await rides.Where(r => r.CompletedAt >= week)
            .Select(r => new { r.CompletedAt, Fare = (r.AgreedFare ?? r.OfferedFare) - (r.Discount ?? 0), Tip = r.Tip ?? 0, Commission = r.Commission ?? 0 })
            .ToListAsync(ct);
        var todays = weekRides.Where(r => r.CompletedAt >= today).ToList();
        return new EarningsDto(
            user.WalletBalance,
            todays.Sum(r => r.Fare + r.Tip - r.Commission),
            weekRides.Sum(r => r.Fare + r.Tip - r.Commission),
            todays.Count, weekRides.Count, weekRides.Sum(r => r.Commission), user.Rating,
            await HistoryQuery(driverId).Take(20).ToListAsync(ct));
    }

    public async Task<WithdrawalDto> RequestWithdrawalAsync(Guid driverId, WithdrawRequest r, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == driverId, ct);
        if (r.Amount < MinimumWithdrawal) throw AppException.BadRequest($"The minimum withdrawal is Le {MinimumWithdrawal:N0}.");
        if (r.Amount > user.WalletBalance) throw AppException.BadRequest("You cannot withdraw more than your balance.");
        if (string.IsNullOrWhiteSpace(r.AccountNumber)) throw AppException.BadRequest("Enter the number to pay out to.");
        if (await db.Withdrawals.AnyAsync(w => w.DriverId == driverId && w.Status == WithdrawalStatus.Pending, ct))
            throw AppException.Conflict("You already have a withdrawal waiting for approval.");

        var w = new Withdrawal { DriverId = driverId, Amount = r.Amount, Method = r.Method, AccountNumber = r.AccountNumber.Trim() };
        db.Withdrawals.Add(w);
        // Hold the money now so it cannot be spent twice; refunded if the admin rejects.
        Post(db, user, WalletTxType.Withdrawal, -r.Amount, $"Withdrawal to {r.Method} {w.AccountNumber}", reference: w.Id.ToString());
        await db.SaveChangesAsync(ct);
        return ToDto(w);
    }

    public async Task<List<WithdrawalDto>> WithdrawalsAsync(Guid driverId, CancellationToken ct) =>
        (await db.Withdrawals.Where(w => w.DriverId == driverId).OrderByDescending(w => w.CreatedAt).Take(50).ToListAsync(ct))
        .Select(ToDto).ToList();

    public static WithdrawalDto ToDto(Withdrawal w) => new(w.Id, w.Amount, w.Method, w.AccountNumber, w.Status, w.AdminNote, w.CreatedAt, w.ProcessedAt);

    private IQueryable<WalletTxDto> HistoryQuery(Guid userId) =>
        db.WalletTransactions.Where(t => t.UserId == userId).OrderByDescending(t => t.CreatedAt)
            .Select(t => new WalletTxDto(t.Id, t.Type, t.Amount, t.BalanceAfter, t.Description, t.RideId, t.Reference, t.CreatedAt));

    private static string Label(PaymentMethod m) => m switch
    {
        PaymentMethod.OrangeMoney => "Orange Money",
        PaymentMethod.Card => "Card",
        _ => m.ToString()
    };
}
