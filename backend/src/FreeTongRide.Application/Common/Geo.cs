using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace FreeTongRide.Application.Common;

public static class Geo
{
    /// <summary>Freetown streets wind; straight-line distance is scaled up to approximate road distance.</summary>
    public const double RoadFactor = 1.3;
    /// <summary>Average city speed used for time estimates until a routing API is wired in.</summary>
    public const double AverageKmh = 22;

    public static double HaversineKm(double lat1, double lng1, double lat2, double lng2)
    {
        const double r = 6371;
        var dLat = ToRad(lat2 - lat1);
        var dLng = ToRad(lng2 - lng1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) * Math.Sin(dLng / 2) * Math.Sin(dLng / 2);
        return r * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    public static (double km, int minutes) RoadEstimate(double lat1, double lng1, double lat2, double lng2)
    {
        var km = Math.Round(HaversineKm(lat1, lng1, lat2, lng2) * RoadFactor, 1);
        var minutes = Math.Max(1, (int)Math.Ceiling(km / AverageKmh * 60));
        return (km, minutes);
    }

    private static double ToRad(double deg) => deg * Math.PI / 180;
}

public static partial class Phone
{
    /// <summary>Normalises Sierra Leone numbers to +232XXXXXXXX. Accepts 076123456, 76123456, +23276123456.</summary>
    public static string Normalize(string input)
    {
        var digits = NonDigits().Replace(input ?? "", "");
        if (digits.StartsWith("232")) digits = digits[3..];
        if (digits.StartsWith('0')) digits = digits[1..];
        if (digits.Length != 8) throw AppException.BadRequest("Enter a valid Sierra Leone phone number, e.g. 76 123 456.");
        return "+232" + digits;
    }

    [GeneratedRegex(@"\D")]
    private static partial Regex NonDigits();
}

public static class Codes
{
    private const string Alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

    public static string Numeric(int length) =>
        string.Concat(Enumerable.Range(0, length).Select(_ => RandomNumberGenerator.GetInt32(10)));

    public static string RideCode() =>
        "FTR-" + string.Concat(Enumerable.Range(0, 5).Select(_ => Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)]));
}
