using FreeTongRide.Domain.Enums;

namespace FreeTongRide.Domain.Entities;

public class DriverProfile : Entity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public DriverStatus Status { get; set; } = DriverStatus.PendingDocuments;
    public string? RejectReason { get; set; }
    public Guid? ServiceId { get; set; }
    public Service? Service { get; set; }
    public string? LicenceNumber { get; set; }

    // Vehicle
    public string? VehicleMake { get; set; }
    public string? VehicleModel { get; set; }
    public string? VehicleColor { get; set; }
    public int? VehicleYear { get; set; }
    public string? PlateNumber { get; set; }

    // Live state
    public bool IsOnline { get; set; }
    public double? Lat { get; set; }
    public double? Lng { get; set; }
    public double? Heading { get; set; }
    public DateTime? LastSeenAt { get; set; }

    public int CompletedTrips { get; set; }
    public DateTime? ApprovedAt { get; set; }

    public List<DriverDocument> Documents { get; set; } = [];

    public string VehicleSummary =>
        string.Join(" • ", new[] { $"{VehicleMake} {VehicleModel}".Trim(), VehicleColor, PlateNumber }
            .Where(s => !string.IsNullOrWhiteSpace(s)));
}

public class DriverDocument : Entity
{
    public Guid DriverProfileId { get; set; }
    public DocumentType Type { get; set; }
    public string FileUrl { get; set; } = "";
    public bool? Approved { get; set; }
    public string? Note { get; set; }
}

/// <summary>A ride product: Okada, Keke or Car. Fares are in Leones (SLE).</summary>
public class Service : Entity
{
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public int Seats { get; set; }
    public decimal BaseFare { get; set; }
    public decimal PerKm { get; set; }
    public decimal PerMinute { get; set; }
    public decimal MinimumFare { get; set; }
    /// <summary>Platform commission, percent of the final fare.</summary>
    public decimal CommissionPercent { get; set; }
    public bool IsActive { get; set; } = true;
    public int SortOrder { get; set; }
}
