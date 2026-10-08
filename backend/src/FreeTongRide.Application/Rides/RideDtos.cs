using FreeTongRide.Domain.Entities;
using FreeTongRide.Domain.Enums;

namespace FreeTongRide.Application.Rides;

/// <summary>Event names pushed over SignalR. The Flutter apps and the Angular admin listen for these.</summary>
public static class RideEvents
{
    public const string NewRequest = "ride.request";          // -> nearby drivers
    public const string RequestClosed = "ride.request.closed"; // -> drivers: taken or cancelled
    public const string NewBid = "ride.bid";                   // -> passenger
    public const string BidWithdrawn = "ride.bid.withdrawn";   // -> passenger
    public const string BidAccepted = "ride.bid.accepted";     // -> winning driver
    public const string BidDeclined = "ride.bid.declined";     // -> other drivers
    public const string Updated = "ride.updated";              // -> both parties + admins, full RideDto
    public const string DriverLocation = "ride.driver.location";
    public const string Message = "ride.message";
    public const string Sos = "sos.raised";                    // -> admins
    public const string SosUpdated = "sos.updated";
}

public record LatLng(double Lat, double Lng);
public record PlacePoint(string Address, double Lat, double Lng);

public record EstimateRequest(PlacePoint Pickup, PlacePoint Dropoff, string? CouponCode);
public record ServiceQuote(
    Guid ServiceId, string Name, string Description, int Seats, decimal Fare, decimal BaseFare,
    decimal DistanceFare, decimal TimeFare, decimal Discount, double DistanceKm, int DurationMinutes,
    int? NearestDriverMinutes, int DriversNearby);

public record CreateRideRequest(
    Guid ServiceId, PlacePoint Pickup, PlacePoint Dropoff, PaymentMethod PaymentMethod,
    decimal? OfferedFare, string? CouponCode, bool ForSomeoneElse = false, string? RiderName = null,
    string? RiderPhone = null, string? Note = null);

public record PersonDto(Guid Id, string FullName, string Phone, string? PhotoUrl, double Rating, int RatingCount);

public record DriverDto(
    Guid Id, string FullName, string Phone, string? PhotoUrl, double Rating, int RatingCount, int CompletedTrips,
    string? VehicleMake, string? VehicleModel, string? VehicleColor, string? PlateNumber, string Vehicle,
    double? Lat, double? Lng, double? Heading);

public record BidDto(Guid Id, Guid RideId, decimal Amount, int EtaMinutes, BidStatus Status, DateTime CreatedAt, DriverDto Driver);

public record RideDto(
    Guid Id, string Code, RideStatus Status, string ServiceName, Guid ServiceId,
    PlacePoint Pickup, PlacePoint Dropoff, double DistanceKm, int DurationMinutes,
    decimal EstimatedFare, decimal OfferedFare, decimal? AgreedFare, decimal? Discount, decimal? Tip,
    decimal FareDue, decimal? Commission, PaymentMethod PaymentMethod, PaymentStatus PaymentStatus,
    string? PickupCode, // only sent to the passenger; the driver must ask for it

    PersonDto Passenger, DriverDto? Driver,
    bool ForSomeoneElse, string? RiderName, string? RiderPhone, string? Note,
    DateTime CreatedAt, DateTime? AssignedAt, DateTime? ArrivedAt, DateTime? StartedAt, DateTime? EndedAt,
    DateTime? CompletedAt, DateTime? CancelledAt, UserRole? CancelledBy, string? CancelReason,
    int? MyRating);

/// <summary>What a driver sees on the incoming-request card.</summary>
public record RideRequestDto(
    Guid RideId, string Code, string ServiceName, PlacePoint Pickup, PlacePoint Dropoff,
    double DistanceKm, int DurationMinutes, double PickupDistanceKm, decimal OfferedFare, decimal EstimatedFare,
    PaymentMethod PaymentMethod, string PassengerName, string? PassengerPhotoUrl, double PassengerRating,
    DateTime CreatedAt, decimal? MyBid);

public record PlaceBidRequest(decimal Amount);
public record CancelRideRequest(string? Reason);
public record StartRideRequest(string Code);
public record PayRideRequest(PaymentMethod Method, decimal? Tip);
public record RateRequest(int Stars, string? Comment, decimal? Tip);
public record SosRequest(double? Lat, double? Lng, string? Message);
public record MessageRequest(string Text);
public record MessageDto(Guid Id, Guid RideId, Guid SenderId, string Text, DateTime CreatedAt);
public record LocationUpdate(double Lat, double Lng, double? Heading);

public static class RideMapping
{
    public static DriverDto ToDriverDto(User u) => new(
        u.Id, u.FullName, u.Phone, u.PhotoUrl, u.Rating, u.RatingCount, u.DriverProfile?.CompletedTrips ?? 0,
        u.DriverProfile?.VehicleMake, u.DriverProfile?.VehicleModel, u.DriverProfile?.VehicleColor,
        u.DriverProfile?.PlateNumber, u.DriverProfile?.VehicleSummary ?? "",
        u.DriverProfile?.Lat, u.DriverProfile?.Lng, u.DriverProfile?.Heading);

    public static PersonDto ToPerson(User u) => new(u.Id, u.FullName, u.Phone, u.PhotoUrl, u.Rating, u.RatingCount);

    /// <param name="showPickupCode">True only for the passenger; the driver has to ask for the code at pickup.</param>
    public static RideDto ToDto(Ride r, bool showPickupCode, int? myRating = null) => new(
        r.Id, r.Code, r.Status, r.Service?.Name ?? "", r.ServiceId,
        new PlacePoint(r.PickupAddress, r.PickupLat, r.PickupLng),
        new PlacePoint(r.DropoffAddress, r.DropoffLat, r.DropoffLng),
        r.DistanceKm, r.DurationMinutes, r.EstimatedFare, r.OfferedFare, r.AgreedFare, r.Discount, r.Tip,
        r.FareDue, r.Commission, r.PaymentMethod, r.PaymentStatus,
        showPickupCode ? r.PickupCode : null,
        ToPerson(r.Passenger), r.Driver == null ? null : ToDriverDto(r.Driver),
        r.ForSomeoneElse, r.RiderName, r.RiderPhone, r.Note,
        r.CreatedAt, r.AssignedAt, r.ArrivedAt, r.StartedAt, r.EndedAt, r.CompletedAt, r.CancelledAt,
        r.CancelledBy, r.CancelReason, myRating);

    public static BidDto ToDto(Bid b) => new(b.Id, b.RideId, b.Amount, b.EtaMinutes, b.Status, b.CreatedAt, ToDriverDto(b.Driver));
}
