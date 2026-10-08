using FreeTongRide.Domain.Entities;

namespace FreeTongRide.Application.Fares;

public record FareBreakdown(decimal BaseFare, decimal DistanceFare, decimal TimeFare, decimal Total);

public static class FareCalculator
{
    /// <summary>Base + per-km + per-minute, never below the service minimum, rounded up to a whole Leone.</summary>
    public static FareBreakdown Calculate(Service s, double distanceKm, int minutes)
    {
        var distance = Math.Round(s.PerKm * (decimal)distanceKm, 2);
        var time = s.PerMinute * minutes;
        var total = Math.Ceiling(Math.Max(s.MinimumFare, s.BaseFare + distance + time));
        return new FareBreakdown(s.BaseFare, distance, time, total);
    }

    public static decimal Commission(decimal fare, decimal percent) =>
        Math.Round(fare * percent / 100m, 2, MidpointRounding.AwayFromZero);

    public static decimal CouponDiscount(Coupon c, decimal fare)
    {
        var d = c.AmountOff ?? 0m;
        if (c.PercentOff is { } pct) d = Math.Round(fare * pct / 100m, 2);
        if (c.MaxDiscount is { } max) d = Math.Min(d, max);
        return Math.Min(d, fare);
    }
}
