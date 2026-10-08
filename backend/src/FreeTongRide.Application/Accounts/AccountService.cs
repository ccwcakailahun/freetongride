using FreeTongRide.Application.Auth;
using FreeTongRide.Application.Common;
using FreeTongRide.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace FreeTongRide.Application.Accounts;

public record UpdateProfileRequest(string? FullName, string? Email, string? EmergencyContact, string? HomeArea);
public record SavedPlaceDto(Guid Id, string Label, string Address, double Lat, double Lng);
public record SavePlaceRequest(string Label, string Address, double Lat, double Lng);
public record DeviceTokenRequest(string Token);

public class AccountService(IAppDbContext db)
{
    public async Task<UserDto> GetAsync(Guid userId, CancellationToken ct) =>
        UserDto.From(await db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct) ?? throw AppException.NotFound("Account not found."));

    public async Task<UserDto> UpdateAsync(Guid userId, UpdateProfileRequest r, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        if (!string.IsNullOrWhiteSpace(r.FullName)) user.FullName = r.FullName.Trim();
        if (r.Email != null)
        {
            var email = string.IsNullOrWhiteSpace(r.Email) ? null : r.Email.Trim().ToLowerInvariant();
            if (email != null && await db.Users.AnyAsync(u => u.Email == email && u.Id != userId, ct))
                throw AppException.Conflict("This email is already used by another account.");
            user.Email = email;
        }
        if (r.EmergencyContact != null)
            user.EmergencyContact = string.IsNullOrWhiteSpace(r.EmergencyContact) ? null : Phone.Normalize(r.EmergencyContact);
        if (r.HomeArea != null) user.HomeArea = r.HomeArea.Trim();
        await db.SaveChangesAsync(ct);
        return UserDto.From(user);
    }

    public async Task<UserDto> SetPhotoAsync(Guid userId, string url, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        user.PhotoUrl = url;
        await db.SaveChangesAsync(ct);
        return UserDto.From(user);
    }

    public async Task SetDeviceTokenAsync(Guid userId, string token, CancellationToken ct)
    {
        var user = await db.Users.FirstAsync(u => u.Id == userId, ct);
        user.DeviceToken = token;
        await db.SaveChangesAsync(ct);
    }

    public async Task<List<SavedPlaceDto>> PlacesAsync(Guid userId, CancellationToken ct) =>
        await db.SavedPlaces.Where(p => p.UserId == userId).OrderBy(p => p.CreatedAt)
            .Select(p => new SavedPlaceDto(p.Id, p.Label, p.Address, p.Lat, p.Lng)).ToListAsync(ct);

    /// <summary>Home and Work are unique per user, so saving them again replaces the old address.</summary>
    public async Task<SavedPlaceDto> SavePlaceAsync(Guid userId, SavePlaceRequest r, CancellationToken ct)
    {
        var label = r.Label.Trim();
        if (label.Length == 0) throw AppException.BadRequest("Give this place a name.");
        SavedPlace? place = null;
        if (label is "Home" or "Work")
            place = await db.SavedPlaces.FirstOrDefaultAsync(p => p.UserId == userId && p.Label == label, ct);
        if (place == null)
        {
            place = new SavedPlace { UserId = userId, Label = label };
            db.SavedPlaces.Add(place);
        }
        place.Address = r.Address.Trim();
        place.Lat = r.Lat;
        place.Lng = r.Lng;
        await db.SaveChangesAsync(ct);
        return new SavedPlaceDto(place.Id, place.Label, place.Address, place.Lat, place.Lng);
    }

    public async Task DeletePlaceAsync(Guid userId, Guid placeId, CancellationToken ct)
    {
        var place = await db.SavedPlaces.FirstOrDefaultAsync(p => p.Id == placeId && p.UserId == userId, ct)
                    ?? throw AppException.NotFound("Place not found.");
        db.SavedPlaces.Remove(place);
        await db.SaveChangesAsync(ct);
    }
}
