using FreeTongRide.Domain.Enums;

namespace FreeTongRide.Domain.Entities;

public abstract class Entity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class User : Entity
{
    public string FullName { get; set; } = "";
    /// <summary>E.164, e.g. +23276123456.</summary>
    public string Phone { get; set; } = "";
    public string? Email { get; set; }
    public string PasswordHash { get; set; } = "";
    public UserRole Role { get; set; }
    public bool PhoneVerified { get; set; }
    public bool IsActive { get; set; } = true;
    public string? PhotoUrl { get; set; }
    public string? EmergencyContact { get; set; }
    public string? HomeArea { get; set; }
    public decimal WalletBalance { get; set; }
    public int Points { get; set; }
    public double Rating { get; set; } = 5.0;
    public int RatingCount { get; set; }
    public string? DeviceToken { get; set; }
    public DateTime? LastLoginAt { get; set; }

    public DriverProfile? DriverProfile { get; set; }
    public List<SavedPlace> SavedPlaces { get; set; } = [];
}

public class SavedPlace : Entity
{
    public Guid UserId { get; set; }
    /// <summary>Home, Work or a custom label.</summary>
    public string Label { get; set; } = "";
    public string Address { get; set; } = "";
    public double Lat { get; set; }
    public double Lng { get; set; }
}

public class OtpCode : Entity
{
    public string Phone { get; set; } = "";
    public OtpPurpose Purpose { get; set; }
    public string CodeHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public int Attempts { get; set; }
    public bool Used { get; set; }
}
