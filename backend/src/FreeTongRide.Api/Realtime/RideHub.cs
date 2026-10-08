using System.Security.Claims;
using FreeTongRide.Application.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace FreeTongRide.Api.Realtime;

/// <summary>
/// One hub for all clients at /hubs/ride. Each connection joins "user:{id}"; admins also join "admins".
/// Clients only listen; all actions go through the REST API so validation lives in one place.
/// </summary>
[Authorize]
public class RideHub : Hub
{
    public const string AdminsGroup = "admins";
    public static string UserGroup(Guid id) => $"user:{id}";

    public override async Task OnConnectedAsync()
    {
        var id = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (id != null) await Groups.AddToGroupAsync(Context.ConnectionId, UserGroup(Guid.Parse(id)));
        if (Context.User?.IsInRole("Admin") == true) await Groups.AddToGroupAsync(Context.ConnectionId, AdminsGroup);
        await base.OnConnectedAsync();
    }
}

public class SignalRRealtime(IHubContext<RideHub> hub) : IRealtime
{
    public Task ToUser(Guid userId, string evt, object payload) =>
        hub.Clients.Group(RideHub.UserGroup(userId)).SendAsync(evt, payload);

    public Task ToUsers(IEnumerable<Guid> userIds, string evt, object payload)
    {
        var groups = userIds.Distinct().Select(RideHub.UserGroup).ToList();
        return groups.Count == 0 ? Task.CompletedTask : hub.Clients.Groups(groups).SendAsync(evt, payload);
    }

    public Task ToAdmins(string evt, object payload) =>
        hub.Clients.Group(RideHub.AdminsGroup).SendAsync(evt, payload);
}
