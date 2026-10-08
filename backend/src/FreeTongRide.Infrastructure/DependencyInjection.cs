using FreeTongRide.Application.Auth;
using FreeTongRide.Application.Common;
using FreeTongRide.Infrastructure.Persistence;
using FreeTongRide.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace FreeTongRide.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        var cs = config.GetConnectionString("Default") ?? throw new InvalidOperationException("ConnectionStrings:Default is not set.");
        services.AddDbContext<AppDbContext>(o => o.UseSqlServer(cs, sql => sql.EnableRetryOnFailure()));
        services.AddScoped<IAppDbContext>(sp => sp.GetRequiredService<AppDbContext>());

        var jwt = config.GetSection("Jwt").Get<JwtSettings>() ?? new JwtSettings();
        if (jwt.Key.Length < 32) throw new InvalidOperationException("Jwt:Key must be at least 32 characters. Set it with user-secrets or the Jwt__Key environment variable.");
        services.AddSingleton(jwt);
        services.AddSingleton(config.GetSection("Auth").Get<AuthSettings>() ?? new AuthSettings());
        services.AddSingleton(config.GetSection("Seed").Get<SeedSettings>() ?? new SeedSettings());

        services.AddSingleton<IPasswordService, PasswordService>();
        services.AddSingleton<ITokenService, JwtTokenService>();
        services.AddSingleton<ISmsSender, LogSmsSender>();
        services.AddScoped<DbSeeder>();
        return services;
    }
}
