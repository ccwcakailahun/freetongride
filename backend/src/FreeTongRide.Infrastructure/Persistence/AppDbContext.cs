using FreeTongRide.Application.Common;
using FreeTongRide.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Infrastructure.Persistence;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options), IAppDbContext
{
    public DbSet<User> Users => Set<User>();
    public DbSet<SavedPlace> SavedPlaces => Set<SavedPlace>();
    public DbSet<OtpCode> OtpCodes => Set<OtpCode>();
    public DbSet<DriverProfile> DriverProfiles => Set<DriverProfile>();
    public DbSet<DriverDocument> DriverDocuments => Set<DriverDocument>();
    public DbSet<Service> Services => Set<Service>();
    public DbSet<Ride> Rides => Set<Ride>();
    public DbSet<Bid> Bids => Set<Bid>();
    public DbSet<RideMessage> RideMessages => Set<RideMessage>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<SosAlert> SosAlerts => Set<SosAlert>();
    public DbSet<WalletTransaction> WalletTransactions => Set<WalletTransaction>();
    public DbSet<Withdrawal> Withdrawals => Set<Withdrawal>();
    public DbSet<Coupon> Coupons => Set<Coupon>();

    protected override void ConfigureConventions(ModelConfigurationBuilder b)
    {
        b.Properties<decimal>().HavePrecision(18, 2);
        b.Properties<string>().HaveMaxLength(256);
        b.Properties<Enum>().HaveConversion<string>().HaveMaxLength(32);
    }

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>(e =>
        {
            e.HasIndex(x => x.Phone).IsUnique();
            e.HasIndex(x => x.Email).IsUnique().HasFilter("[Email] IS NOT NULL");
            e.Property(x => x.PasswordHash).HasMaxLength(512);
            e.Property(x => x.PhotoUrl).HasMaxLength(1024);
            e.Property(x => x.DeviceToken).HasMaxLength(1024);
            // Guards wallet balance against two settlements racing.
            e.Property<byte[]>("RowVersion").IsRowVersion();
            e.HasOne(x => x.DriverProfile).WithOne(x => x.User).HasForeignKey<DriverProfile>(x => x.UserId);
            e.HasMany(x => x.SavedPlaces).WithOne().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<OtpCode>().HasIndex(x => new { x.Phone, x.Purpose, x.CreatedAt });

        b.Entity<DriverProfile>(e =>
        {
            e.HasIndex(x => x.PlateNumber).IsUnique().HasFilter("[PlateNumber] IS NOT NULL");
            e.HasIndex(x => new { x.IsOnline, x.Status, x.ServiceId });
            e.HasOne(x => x.Service).WithMany().HasForeignKey(x => x.ServiceId).OnDelete(DeleteBehavior.Restrict);
            e.HasMany(x => x.Documents).WithOne().HasForeignKey(x => x.DriverProfileId).OnDelete(DeleteBehavior.Cascade);
        });
        b.Entity<DriverDocument>().Property(x => x.FileUrl).HasMaxLength(1024);

        b.Entity<Ride>(e =>
        {
            e.HasIndex(x => x.Code).IsUnique();
            e.HasIndex(x => new { x.Status, x.CreatedAt });
            e.HasIndex(x => new { x.PassengerId, x.Status });
            e.HasIndex(x => new { x.DriverId, x.Status });
            e.Property(x => x.PickupAddress).HasMaxLength(512);
            e.Property(x => x.DropoffAddress).HasMaxLength(512);
            e.Property(x => x.Note).HasMaxLength(1000);
            // Two passengers' devices / a double tap cannot accept two offers on the same ride.
            e.Property<byte[]>("RowVersion").IsRowVersion();
            e.HasOne(x => x.Passenger).WithMany().HasForeignKey(x => x.PassengerId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Driver).WithMany().HasForeignKey(x => x.DriverId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Service).WithMany().HasForeignKey(x => x.ServiceId).OnDelete(DeleteBehavior.Restrict);
            e.HasMany(x => x.Bids).WithOne(x => x.Ride).HasForeignKey(x => x.RideId).OnDelete(DeleteBehavior.Cascade);
            e.HasMany(x => x.Messages).WithOne().HasForeignKey(x => x.RideId).OnDelete(DeleteBehavior.Cascade);
            e.Ignore(x => x.FareDue);
        });

        b.Entity<Bid>(e =>
        {
            e.HasIndex(x => new { x.RideId, x.DriverId });
            e.HasOne(x => x.Driver).WithMany().HasForeignKey(x => x.DriverId).OnDelete(DeleteBehavior.Restrict);
        });
        b.Entity<RideMessage>().Property(x => x.Text).HasMaxLength(500);
        b.Entity<Review>(e =>
        {
            e.HasIndex(x => new { x.RideId, x.FromUserId }).IsUnique();
            e.Property(x => x.Comment).HasMaxLength(1000);
        });
        b.Entity<SosAlert>(e =>
        {
            e.HasIndex(x => x.Status);
            e.HasOne(x => x.Ride).WithMany().HasForeignKey(x => x.RideId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.RaisedBy).WithMany().HasForeignKey(x => x.RaisedById).OnDelete(DeleteBehavior.Restrict);
            e.Property(x => x.Message).HasMaxLength(1000);
        });
        b.Entity<WalletTransaction>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.CreatedAt });
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        });
        b.Entity<Withdrawal>().HasOne(x => x.Driver).WithMany().HasForeignKey(x => x.DriverId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Coupon>().HasIndex(x => x.Code).IsUnique();
        b.Entity<Service>().HasIndex(x => x.Name).IsUnique();
    }
}
