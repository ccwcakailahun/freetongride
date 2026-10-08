using FreeTongRide.Application.Common;
using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Drivers;

public record DocumentDto(Guid Id, DocumentType Type, string FileUrl, bool? Approved, string? Note, DateTime CreatedAt);
public record ServiceDto(Guid Id, string Name, string Description, int Seats, decimal BaseFare, decimal PerKm, decimal PerMinute, decimal MinimumFare, decimal CommissionPercent, bool IsActive, int SortOrder);

public record DriverProfileDto(
    DriverStatus Status, string? RejectReason, Guid? ServiceId, string? ServiceName, string? LicenceNumber,
    string? VehicleMake, string? VehicleModel, string? VehicleColor, int? VehicleYear, string? PlateNumber,
    bool IsOnline, int CompletedTrips, IReadOnlyList<DocumentDto> Documents, IReadOnlyList<DocumentType> MissingDocuments);

public record UpdateVehicleRequest(Guid ServiceId, string? LicenceNumber, string VehicleMake, string VehicleModel, string VehicleColor, int VehicleYear, string PlateNumber);

public class DriverOnboardingService(IAppDbContext db, IRealtime realtime)
{
    public static readonly DocumentType[] Required = [DocumentType.DrivingLicence, DocumentType.NationalId, DocumentType.ProfilePhoto, DocumentType.VehiclePhoto];

    public async Task<DriverProfileDto> GetAsync(Guid driverId, CancellationToken ct) => ToDto(await LoadAsync(driverId, ct));

    public async Task<DriverProfileDto> UpdateVehicleAsync(Guid driverId, UpdateVehicleRequest r, CancellationToken ct)
    {
        var p = await LoadAsync(driverId, ct);
        if (p.Status == DriverStatus.Approved && p.IsOnline) throw AppException.Conflict("Go offline before changing your vehicle.");
        var service = await db.Services.FirstOrDefaultAsync(s => s.Id == r.ServiceId && s.IsActive, ct)
                      ?? throw AppException.BadRequest("Choose a ride type.");
        if (string.IsNullOrWhiteSpace(r.PlateNumber)) throw AppException.BadRequest("Enter the plate number.");
        if (r.VehicleYear < 1980 || r.VehicleYear > DateTime.UtcNow.Year + 1) throw AppException.BadRequest("Enter a valid vehicle year.");
        var plate = r.PlateNumber.Trim().ToUpperInvariant();
        if (await db.DriverProfiles.AnyAsync(d => d.PlateNumber == plate && d.UserId != driverId, ct))
            throw AppException.Conflict("This plate number is registered to another driver.");

        p.ServiceId = service.Id;
        p.Service = service;
        p.LicenceNumber = r.LicenceNumber?.Trim();
        p.VehicleMake = r.VehicleMake.Trim();
        p.VehicleModel = r.VehicleModel.Trim();
        p.VehicleColor = r.VehicleColor.Trim();
        p.VehicleYear = r.VehicleYear;
        p.PlateNumber = plate;
        // Changing the vehicle after approval sends the driver back for review.
        if (p.Status is DriverStatus.Approved or DriverStatus.Rejected) p.Status = DriverStatus.PendingDocuments;
        await db.SaveChangesAsync(ct);
        return ToDto(p);
    }

    public async Task<DriverProfileDto> AddDocumentAsync(Guid driverId, DocumentType type, string url, CancellationToken ct)
    {
        var p = await LoadAsync(driverId, ct);
        var old = p.Documents.Where(d => d.Type == type && type != DocumentType.VehiclePhoto).ToList();
        db.DriverDocuments.RemoveRange(old);
        old.ForEach(d => p.Documents.Remove(d));
        var doc = new DriverDocument { DriverProfileId = p.Id, Type = type, FileUrl = url };
        db.DriverDocuments.Add(doc);
        p.Documents.Add(doc);
        if (type == DocumentType.ProfilePhoto) p.User.PhotoUrl = url;
        await db.SaveChangesAsync(ct);
        return ToDto(p);
    }

    public async Task<DriverProfileDto> SubmitAsync(Guid driverId, CancellationToken ct)
    {
        var p = await LoadAsync(driverId, ct);
        if (p.Status is DriverStatus.Approved or DriverStatus.UnderReview) return ToDto(p);
        if (p.ServiceId == null || p.PlateNumber == null) throw AppException.BadRequest("Add your vehicle details first.");
        var missing = Missing(p);
        if (missing.Count > 0) throw AppException.BadRequest("Upload all required documents first.");
        p.Status = DriverStatus.UnderReview;
        p.RejectReason = null;
        await db.SaveChangesAsync(ct);
        await realtime.ToAdmins("driver.submitted", new { driverId, p.User.FullName, p.User.Phone });
        return ToDto(p);
    }

    public async Task<List<ServiceDto>> ServicesAsync(CancellationToken ct) =>
        (await db.Services.Where(s => s.IsActive).OrderBy(s => s.SortOrder).ToListAsync(ct)).Select(ToDto).ToList();

    public static ServiceDto ToDto(Service s) => new(s.Id, s.Name, s.Description, s.Seats, s.BaseFare, s.PerKm, s.PerMinute, s.MinimumFare, s.CommissionPercent, s.IsActive, s.SortOrder);

    private async Task<DriverProfile> LoadAsync(Guid driverId, CancellationToken ct) =>
        await db.DriverProfiles.Include(d => d.Documents).Include(d => d.Service).Include(d => d.User)
            .FirstOrDefaultAsync(d => d.UserId == driverId, ct) ?? throw AppException.Forbidden("This account is not a driver account.");

    private static List<DocumentType> Missing(DriverProfile p) => Required.Where(t => p.Documents.All(d => d.Type != t)).ToList();

    public static DriverProfileDto ToDto(DriverProfile p) => new(
        p.Status, p.RejectReason, p.ServiceId, p.Service?.Name, p.LicenceNumber, p.VehicleMake, p.VehicleModel,
        p.VehicleColor, p.VehicleYear, p.PlateNumber, p.IsOnline, p.CompletedTrips,
        p.Documents.OrderBy(d => d.Type).Select(d => new DocumentDto(d.Id, d.Type, d.FileUrl, d.Approved, d.Note, d.CreatedAt)).ToList(),
        Missing(p));
}
