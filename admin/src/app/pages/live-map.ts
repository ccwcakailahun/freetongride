import { AfterViewInit, Component, ElementRef, OnDestroy, inject, signal, viewChild } from '@angular/core';
import { RouterLink } from '@angular/router';
import * as L from 'leaflet';
import { Subscription } from 'rxjs';
import { AdminApi, TILE_URL, errorText } from '../core/api';
import { AgoPipe, LePipe } from '../core/format';
import { LiveDriver, Ride } from '../core/models';
import { Realtime } from '../core/realtime';
import { RideStatusPill } from './shared';

/** Every online driver and active ride on a map of Freetown; moves live with driver location events. */
@Component({
  selector: 'ftr-live-map',
  imports: [RouterLink, AgoPipe, LePipe, RideStatusPill],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow">
          <h1>Live map</h1>
          <p><span class="dot free"></span>{{ freeCount() }} available <span class="dot busy"></span>{{ busyCount() }} on a trip
            · {{ rides().length }} active rides · <span class="dot sos"></span>{{ rt.sosAlerts().length }} SOS</p>
        </div>
        <button class="btn" (click)="load(true)">Fit all</button>
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      <div class="layout">
        <div class="card map-card"><div #map class="map"></div></div>
        <div class="card list">
          <div class="card-head"><h2>Active rides</h2></div>
          @for (r of rides(); track r.id) {
            <button class="ride" (click)="focus(r)">
              <div class="row"><b class="mono">{{ r.code }}</b><ftr-ride-status [status]="r.status" /></div>
              <div class="route"><div><i></i>{{ r.pickup.address }}</div><div><i></i>{{ r.dropoff.address }}</div></div>
              <div class="row small"><span>{{ r.driver?.fullName ?? 'No driver yet' }}</span><span>{{ r.fareDue | le }} · {{ r.createdAt | ago }}</span></div>
            </button>
          } @empty { <p class="empty">No active rides.</p> }
          <a class="more" routerLink="/rides">All rides →</a>
        </div>
      </div>
    </div>
  `,
  styles: `
    .layout { display: grid; grid-template-columns: minmax(0, 1fr) 340px; gap: 16px; }
    @media (max-width: 1000px) { .layout { grid-template-columns: 1fr; } }
    .map-card { overflow: hidden; }
    .map { height: calc(100vh - 190px); min-height: 420px; }
    .list { max-height: calc(100vh - 190px); overflow-y: auto; }
    .ride { display: grid; gap: 8px; width: 100%; text-align: left; background: none; border: 0; border-bottom: 1px solid var(--border); padding: 14px 18px; cursor: pointer; font: inherit; color: inherit; }
    .ride:hover { background: #f8faff; }
    .row { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    .more { display: block; padding: 14px 18px; }
    .dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin: 0 6px 0 10px; vertical-align: middle; }
    .dot.free { background: var(--green); } .dot.busy { background: var(--blue); } .dot.sos { background: var(--red); }
  `,
})
export class LiveMapPage implements AfterViewInit, OnDestroy {
  private readonly api = inject(AdminApi);
  protected readonly rt = inject(Realtime);
  private readonly el = viewChild.required<ElementRef<HTMLDivElement>>('map');
  readonly rides = signal<Ride[]>([]);
  readonly drivers = signal<LiveDriver[]>([]);
  readonly error = signal('');
  readonly freeCount = () => this.drivers().filter((d) => !d.onTrip).length;
  readonly busyCount = () => this.drivers().filter((d) => d.onTrip).length;

  private map?: L.Map;
  private driverLayer = L.layerGroup();
  private rideLayer = L.layerGroup();
  private sosLayer = L.layerGroup();
  private driverMarkers = new Map<string, L.Marker>();
  private sub?: Subscription;
  private poll?: ReturnType<typeof setInterval>;

  ngAfterViewInit() {
    this.map = L.map(this.el().nativeElement, { zoomControl: true }).setView([8.465, -13.232], 13);
    L.tileLayer(TILE_URL, { attribution: '&copy; OpenStreetMap contributors', maxZoom: 19 }).addTo(this.map);
    this.rideLayer.addTo(this.map);
    this.driverLayer.addTo(this.map);
    this.sosLayer.addTo(this.map);
    this.load(true);
    this.poll = setInterval(() => this.load(false), 30_000);
    this.sub = this.rt.events.subscribe((e) => {
      if (e.name === 'ride.driver.location') this.moveDriver(e.data.driverId, e.data.lat, e.data.lng);
      if (e.name === 'ride.updated' || e.name === 'driver.status' || e.name === 'sos.raised') this.load(false);
    });
  }

  ngOnDestroy() {
    this.sub?.unsubscribe();
    clearInterval(this.poll);
    this.map?.remove();
  }

  async load(fit: boolean) {
    try {
      const live = await this.api.live();
      this.rides.set(live.activeRides);
      this.drivers.set(live.drivers);
      this.error.set('');
      this.draw(fit);
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  focus(r: Ride) {
    const pts: L.LatLngExpression[] = [[r.pickup.lat, r.pickup.lng], [r.dropoff.lat, r.dropoff.lng]];
    this.map?.fitBounds(L.latLngBounds(pts), { padding: [60, 60] });
  }

  private draw(fit: boolean) {
    if (!this.map) return;
    this.driverLayer.clearLayers();
    this.driverMarkers.clear();
    this.rideLayer.clearLayers();
    this.sosLayer.clearLayers();
    const bounds: L.LatLngExpression[] = [];

    for (const d of this.drivers()) {
      const m = L.marker([d.lat, d.lng], {
        icon: L.divIcon({ className: '', html: `<div class="ftr-car ${d.onTrip ? 'busy' : 'free'}">▲</div>`, iconSize: [30, 30], iconAnchor: [15, 15] }),
        title: d.fullName,
      }).bindPopup(`<b>${esc(d.fullName)}</b><br>${esc(d.serviceName ?? '')} · ${esc(d.plateNumber ?? '')}<br>${d.onTrip ? 'On a trip' : 'Available'}`);
      m.addTo(this.driverLayer);
      this.driverMarkers.set(d.id, m);
      bounds.push([d.lat, d.lng]);
    }
    for (const r of this.rides()) {
      const a: L.LatLngExpression = [r.pickup.lat, r.pickup.lng];
      const b: L.LatLngExpression = [r.dropoff.lat, r.dropoff.lng];
      L.polyline([a, b], { color: '#1a5cff', weight: 3, opacity: 0.55, dashArray: '6 8' }).addTo(this.rideLayer);
      L.marker(a, { icon: L.divIcon({ className: '', html: '<div class="ftr-pin"></div>', iconSize: [16, 16], iconAnchor: [8, 8] }) })
        .bindPopup(`<b>${esc(r.code)}</b><br>Pickup: ${esc(r.pickup.address)}<br>Passenger: ${esc(r.passenger.fullName)}`).addTo(this.rideLayer);
      L.marker(b, { icon: L.divIcon({ className: '', html: '<div class="ftr-pin drop"></div>', iconSize: [16, 16], iconAnchor: [8, 8] }) })
        .bindPopup(`<b>${esc(r.code)}</b><br>Drop-off: ${esc(r.dropoff.address)}`).addTo(this.rideLayer);
      bounds.push(a, b);
    }
    for (const s of this.rt.sosAlerts()) {
      if (s.lat == null || s.lng == null) continue;
      L.marker([s.lat, s.lng], { icon: L.divIcon({ className: '', html: '<div class="ftr-sos">SOS</div>', iconSize: [34, 34], iconAnchor: [17, 17] }), zIndexOffset: 1000 })
        .bindPopup(`<b>SOS · ${esc(s.rideCode)}</b><br>${esc(s.raisedByName)} ${esc(s.raisedByPhone)}`).addTo(this.sosLayer);
      bounds.push([s.lat, s.lng]);
    }
    if (fit && bounds.length) this.map.fitBounds(L.latLngBounds(bounds), { padding: [50, 50], maxZoom: 15 });
  }

  private moveDriver(id: string, lat: number, lng: number) {
    this.driverMarkers.get(id)?.setLatLng([lat, lng]);
  }
}

function esc(s: string) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}
