using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using FreeTongRide.Api.Infrastructure;
using FreeTongRide.Api.Realtime;
using FreeTongRide.Application;
using FreeTongRide.Application.Common;
using FreeTongRide.Infrastructure;
using FreeTongRide.Infrastructure.Persistence;
using FreeTongRide.Infrastructure.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddSingleton<IRealtime, SignalRRealtime>();
builder.Services.AddSingleton<FileStore>();

builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddSignalR()
    .AddJsonProtocol(o => o.PayloadSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<AppExceptionHandler>();
builder.Services.AddHealthChecks();
// nginx in front: trust its X-Forwarded-* headers (it only listens locally to the app).
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownIPNetworks.Clear();
    o.KnownProxies.Clear();
    o.KnownProxies.Add(System.Net.IPAddress.Loopback);
});

var jwt = builder.Configuration.GetSection("Jwt").Get<JwtSettings>()!;
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            NameClaimType = System.Security.Claims.ClaimTypes.Name,
            RoleClaimType = System.Security.Claims.ClaimTypes.Role,
            ClockSkew = TimeSpan.FromMinutes(2)
        };
        // SignalR sends the token in the query string for WebSockets.
        o.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) && ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            }
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = 429;
    o.AddPolicy("auth", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(1) }));
});

var origins = builder.Configuration.GetSection("Cors:AdminOrigins").Get<string[]>() ?? ["http://localhost:4200"];
builder.Services.AddCors(o => o.AddPolicy("admin", p => p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod().AllowCredentials()));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
    await scope.ServiceProvider.GetRequiredService<DbSeeder>().RunAsync();

app.UseForwardedHeaders();
app.UseExceptionHandler();
if (app.Environment.IsDevelopment()) app.MapOpenApi();
app.UseStaticFiles();
app.UseCors("admin");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<RideHub>("/hubs/ride");
app.MapHealthChecks("/health");

app.Run();

public partial class Program;
