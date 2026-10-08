using FreeTongRide.Application.Common;
using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace FreeTongRide.Infrastructure.Persistence;

public class SeedSettings
{
    public string? AdminName { get; set; }
    public string? AdminPhone { get; set; }
    public string? AdminEmail { get; set; }
    /// <summary>Only used to create the first admin. Supply via user-secrets or Seed__AdminPassword, not a committed file.</summary>
    public string? AdminPassword { get; set; }
    /// <summary>Adds a demo passenger and an approved, online driver near Lumley for local testing.</summary>
    public bool DemoData { get; set; }
    public string? DemoPassword { get; set; }
}

public class DbSeeder(AppDbContext db, IPasswordService passwords, SeedSettings seed, ILogger<DbSeeder> logger)
{
    public async Task RunAsync(CancellationToken ct = default)
    {
        await db.Database.MigrateAsync(ct);

        if (!await db.Services.AnyAsync(ct))
        {
            // Starting fares in Leones (SLE). Edit them in the admin panel under Ride types & fares.
            db.Services.AddRange(
                new Service { Name = "Okada", Description = "Motorbike, beat the traffic", Seats = 1, BaseFare = 5, PerKm = 3, PerMinute = 0.5m, MinimumFare = 10, CommissionPercent = 12, SortOrder = 1 },
                new Service { Name = "Keke", Description = "Tricycle, affordable for short trips", Seats = 3, BaseFare = 8, PerKm = 4, PerMinute = 0.6m, MinimumFare = 15, CommissionPercent = 12, SortOrder = 2 },
                new Service { Name = "Car", Description = "Comfortable rides for up to 4", Seats = 4, BaseFare = 15, PerKm = 6, PerMinute = 1, MinimumFare = 25, CommissionPercent = 15, SortOrder = 3 });
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Seeded ride types Okada, Keke, Car");
        }

        if (!string.IsNullOrWhiteSpace(seed.AdminPhone) && !string.IsNullOrWhiteSpace(seed.AdminPassword))
        {
            var phone = Phone.Normalize(seed.AdminPhone);
            if (!await db.Users.AnyAsync(u => u.Phone == phone, ct))
            {
                var admin = new User
                {
                    FullName = seed.AdminName ?? "FreeTongRide Admin", Phone = phone, Email = seed.AdminEmail?.ToLowerInvariant(),
                    Role = UserRole.Admin, PhoneVerified = true
                };
                admin.PasswordHash = passwords.Hash(admin, seed.AdminPassword);
                db.Users.Add(admin);
                await db.SaveChangesAsync(ct);
                logger.LogInformation("Created admin account {Phone}", phone);
            }
        }

        if (seed.DemoData && !string.IsNullOrWhiteSpace(seed.DemoPassword) && !await db.Users.AnyAsync(u => u.Phone == "+23276123456", ct))
            await SeedDemoAsync(seed.DemoPassword, ct);
    }

    private async Task SeedDemoAsync(string password, CancellationToken ct)
    {
        var car = await db.Services.FirstAsync(s => s.Name == "Car", ct);
        var mariama = new User
        {
            FullName = "Mariama Kamara", Phone = "+23276123456", Email = "mariama@example.com", Role = UserRole.Passenger,
            PhoneVerified = true, HomeArea = "Lumley Beach, Freetown", EmergencyContact = "+23276999888", WalletBalance = 150
        };
        var mohamed = new User
        {
            FullName = "Mohamed Koroma", Phone = "+23277123456", Email = "mohamed@example.com", Role = UserRole.Driver,
            PhoneVerified = true, Rating = 4.9, RatingCount = 320
        };
        foreach (var u in new[] { mariama, mohamed }) u.PasswordHash = passwords.Hash(u, password);
        db.Users.AddRange(mariama, mohamed);
        db.DriverProfiles.Add(new DriverProfile
        {
            UserId = mohamed.Id, Status = DriverStatus.Approved, ApprovedAt = DateTime.UtcNow, ServiceId = car.Id,
            VehicleMake = "Toyota", VehicleModel = "Corolla", VehicleColor = "White", VehicleYear = 2016, PlateNumber = "AFS 284",
            IsOnline = true, Lat = 8.4225, Lng = -13.2878, LastSeenAt = DateTime.UtcNow, CompletedTrips = 320
        });
        db.SavedPlaces.AddRange(
            new SavedPlace { UserId = mariama.Id, Label = "Home", Address = "Lumley Beach, Freetown", Lat = 8.4207, Lng = -13.2930 },
            new SavedPlace { UserId = mariama.Id, Label = "Work", Address = "Freetown Central", Lat = 8.4840, Lng = -13.2299 });
        db.WalletTransactions.Add(new WalletTransaction { UserId = mariama.Id, Type = WalletTxType.TopUp, Amount = 150, BalanceAfter = 150, Description = "Added funds (Orange Money)", Reference = "DEMO" });
        db.Coupons.Add(new Coupon { Code = "WELCOME10", AmountOff = 10, IsActive = true });
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Seeded demo passenger +23276123456 and demo driver +23277123456");
    }
}
