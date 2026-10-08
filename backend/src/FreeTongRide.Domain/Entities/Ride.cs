using FreeTongRide.Domain.Enums;

namespace FreeTongRide.Domain.Entities;

public class Ride : Entity
{
    /// <summary>Short human code shown in the apps and admin, e.g. FTR-8K2Q4.</summary>
    public string Code { get; set; } = "";
    public Guid PassengerId { get; set; }
    public User Passenger { get; set; } = null!;
    public Guid? DriverId { get; set; }
    public User? Driver { get; set; }
    public Guid ServiceId { get; set; }
    public Service Service { get; set; } = null!;

    public string PickupAddress { get; set; } = "";
    public double PickupLat { get; set; }
    public double PickupLng { get; set; }
    public string DropoffAddress { get; set; } = "";
    public double DropoffLat { get; set; }
    public double DropoffLng { get; set; }
    public double DistanceKm { get; set; }
    public int DurationMinutes { get; set; }

    public decimal EstimatedFare { get; set; }
    /// <summary>Fare the passenger offered when requesting (defaults to the estimate).</summary>
    public decimal OfferedFare { get; set; }
    /// <summary>Fare from the accepted driver offer.</summary>
    public decimal? AgreedFare { get; set; }
    public decimal? Discount { get; set; }
    public string? CouponCode { get; set; }
    public decimal? Tip { get; set; }
    public decimal? Commission { get; set; }

    public PaymentMethod PaymentMethod { get; set; }
    public PaymentStatus PaymentStatus { get; set; }
    public RideStatus Status { get; set; }
    /// <summary>6-digit code the passenger gives the driver to start the trip.</summary>
    public string PickupCode { get; set; } = "";

    public bool ForSomeoneElse { get; set; }
    public string? RiderName { get; set; }
    public string? RiderPhone { get; set; }
    public string? Note { get; set; }

    public DateTime? AssignedAt { get; set; }
    public DateTime? ArrivedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? EndedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime? CancelledAt { get; set; }
    public UserRole? CancelledBy { get; set; }
    public string? CancelReason { get; set; }

    public List<Bid> Bids { get; set; } = [];
    public List<RideMessage> Messages { get; set; } = [];

    /// <summary>What the passenger owes for the trip itself (tip excluded).</summary>
    public decimal FareDue => Math.Max(0, (AgreedFare ?? OfferedFare) - (Discount ?? 0));
}

public class Bid : Entity
{
    public Guid RideId { get; set; }
    public Ride Ride { get; set; } = null!;
    public Guid DriverId { get; set; }
    public User Driver { get; set; } = null!;
    public decimal Amount { get; set; }
    public int EtaMinutes { get; set; }
    public BidStatus Status { get; set; }
}

public class RideMessage : Entity
{
    public Guid RideId { get; set; }
    public Guid SenderId { get; set; }
    public string Text { get; set; } = "";
}

public class Review : Entity
{
    public Guid RideId { get; set; }
    public Guid FromUserId { get; set; }
    public Guid ToUserId { get; set; }
    public int Stars { get; set; }
    public string? Comment { get; set; }
}

public class SosAlert : Entity
{
    public Guid RideId { get; set; }
    public Ride Ride { get; set; } = null!;
    public Guid RaisedById { get; set; }
    public User RaisedBy { get; set; } = null!;
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public string? Message { get; set; }
    public SosStatus Status { get; set; }
    public Guid? HandledById { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public string? ResolutionNote { get; set; }
}

public class WalletTransaction : Entity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public WalletTxType Type { get; set; }
    /// <summary>Signed: positive credits the wallet, negative debits it.</summary>
    public decimal Amount { get; set; }
    public decimal BalanceAfter { get; set; }
    public Guid? RideId { get; set; }
    public string Description { get; set; } = "";
    public string? Reference { get; set; }
}

public class Withdrawal : Entity
{
    public Guid DriverId { get; set; }
    public User Driver { get; set; } = null!;
    public decimal Amount { get; set; }
    public string Method { get; set; } = "Orange Money";
    public string AccountNumber { get; set; } = "";
    public WithdrawalStatus Status { get; set; }
    public string? AdminNote { get; set; }
    public DateTime? ProcessedAt { get; set; }
}

public class Coupon : Entity
{
    public string Code { get; set; } = "";
    public decimal? PercentOff { get; set; }
    public decimal? AmountOff { get; set; }
    public decimal? MaxDiscount { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public int? UsageLimit { get; set; }
    public int TimesUsed { get; set; }
    public bool IsActive { get; set; } = true;
}
