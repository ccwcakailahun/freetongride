using FreeTongRide.Application.Accounts;
using FreeTongRide.Application.Admin;
using FreeTongRide.Application.Auth;
using FreeTongRide.Application.Drivers;
using FreeTongRide.Application.Rides;
using FreeTongRide.Application.Wallet;
using Microsoft.Extensions.DependencyInjection;

namespace FreeTongRide.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<AuthService>();
        services.AddScoped<AccountService>();
        services.AddScoped<RideService>();
        services.AddScoped<WalletService>();
        services.AddScoped<DriverOnboardingService>();
        services.AddScoped<AdminService>();
        return services;
    }
}
