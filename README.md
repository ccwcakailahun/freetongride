# FreeTongRide

*Moving Freetown Together.* A ride-hailing platform for Freetown, Sierra Leone.

| Part | Folder | Stack |
|---|---|---|
| Passenger app | `mobile/passenger` | Flutter (Android + iOS) |
| Driver app | `mobile/driver` | Flutter (Android + iOS) |
| Shared mobile code (design system, API client, models) | `mobile/packages/ftr_core` | Dart package |
| Admin panel (monitoring & operations) | `admin` | Angular |
| API | `backend` | .NET 10 Web API, EF Core, SQL Server, SignalR |

The customer journey this is built from is in [`docs/customer-journey.html`](docs/customer-journey.html).

## How a ride works

```
Searching ──offer accepted──▶ DriverAssigned ──▶ DriverArrived ──pickup code──▶ InProgress ──▶ AwaitingPayment ──▶ Completed
    └────────────── Cancelled (before the trip starts) ◀──────────────┘
```

1. The passenger asks for a price (`POST /api/rides/estimate`), picks Okada, Keke or Car and requests (`POST /api/rides`). The fare offered defaults to the estimate.
2. Online, approved drivers of that type within 6 km get a `ride.request` event and send offers (`POST /api/driver/requests/{id}/bid`).
3. The passenger accepts one offer. The driver goes to pickup, taps *Arrived*, and starts the trip with the passenger's 6-digit code.
4. When the driver ends the trip, wallet rides are paid at once. Cash rides close when the driver confirms the cash. The platform's commission is taken from the driver's wallet for cash trips.
5. Both sides rate each other. Admins see everything live, including SOS alerts.

Live updates go over SignalR at `/hubs/ride` (pass the JWT as `access_token`). Event names are in `backend/src/FreeTongRide.Application/Rides/RideDtos.cs` (`RideEvents`).

## Run it locally

### API

Needs the .NET 10 SDK and SQL Server LocalDB (installed with Visual Studio).

```bash
cd backend
dotnet run --project src/FreeTongRide.Api
```

The API listens on `http://localhost:5080`. On first start it creates the `FreeTongRide` database, the three ride types, an admin and two demo accounts. The development accounts and passwords are in `backend/src/FreeTongRide.Api/appsettings.Development.json`. In Development, SMS codes are written to the console and returned in the API response as `devCode`.

API reference (Development): `http://localhost:5080/openapi/v1.json`.

### Admin panel

```bash
cd admin
npm install
npm start
```

Opens on `http://localhost:4200`.

### Mobile apps

```bash
cd mobile/passenger
flutter pub get
flutter run
```

The Android emulator reaches the API at `http://10.0.2.2:5080`. For a real phone, run with `--dart-define=API_URL=http://<your-PC-IP>:5080`.

## Production settings

Never commit real secrets. Set these as environment variables on the server:

| Setting | Variable |
|---|---|
| Database | `ConnectionStrings__Default` |
| JWT signing key (32+ chars) | `Jwt__Key` |
| First admin | `Seed__AdminPhone`, `Seed__AdminPassword` |
| Admin panel URL for CORS | `Cors__AdminOrigins__0` |

## Not connected yet

- **SMS:** codes are only logged. Plug a gateway into `ISmsSender`.
- **Orange Money and card payments:** wallet top-ups are Development-only until a gateway is connected. Rides can be paid by wallet or cash.
- **Maps routing:** distance is estimated from straight-line distance × 1.3. Google Directions can replace `Geo.RoadEstimate`.
- **Push notifications:** device tokens are stored; sending via Firebase is to do.
