import { Injectable, inject, signal } from '@angular/core';
import { HubConnection, HubConnectionBuilder, HubConnectionState, LogLevel } from '@microsoft/signalr';
import { Subject } from 'rxjs';
import { API_URL, AuthService } from './api';
import { Sos } from './models';

export interface LiveEvent { name: string; data: any; }

/** Admin connection to /hubs/ride. The API puts admins in the "admins" group. */
@Injectable({ providedIn: 'root' })
export class Realtime {
  private readonly auth = inject(AuthService);
  private hub?: HubConnection;
  readonly events = new Subject<LiveEvent>();
  readonly connected = signal(false);
  /** Open SOS alerts raised since the panel opened; drives the red banner. */
  readonly sosAlerts = signal<Sos[]>([]);

  private static readonly names = ['ride.updated', 'ride.driver.location', 'sos.raised', 'sos.updated', 'driver.status', 'driver.submitted'];

  async connect() {
    if (this.hub && this.hub.state !== HubConnectionState.Disconnected) return;
    const hub = new HubConnectionBuilder()
      .withUrl(`${API_URL}/hubs/ride`, { accessTokenFactory: () => this.auth.token() ?? '' })
      .withAutomaticReconnect([0, 2000, 5000, 10000, 30000])
      .configureLogging(LogLevel.Warning)
      .build();
    for (const name of Realtime.names) hub.on(name, (data) => this.onEvent(name, data));
    hub.onreconnecting(() => this.connected.set(false));
    hub.onreconnected(() => this.connected.set(true));
    hub.onclose(() => this.connected.set(false));
    this.hub = hub;
    try {
      await hub.start();
      this.connected.set(true);
    } catch {
      this.connected.set(false);
      setTimeout(() => { if (this.hub === hub && !this.connected()) { this.hub = undefined; this.connect(); } }, 8000);
    }
  }

  async disconnect() {
    await this.hub?.stop();
    this.hub = undefined;
  }

  setOpenSos(list: Sos[]) {
    this.sosAlerts.set(list.filter((s) => s.status !== 'Resolved'));
  }

  private onEvent(name: string, data: any) {
    if (name === 'sos.raised') {
      const s: Sos = {
        id: data.id, rideId: data.rideId, rideCode: data.rideCode, status: 'Open', lat: data.lat, lng: data.lng, message: data.message,
        raisedByName: data.raisedBy?.fullName, raisedByPhone: data.raisedBy?.phone, raisedByRole: data.raisedBy?.role,
        emergencyContact: data.emergencyContact, createdAt: data.createdAt,
      };
      this.sosAlerts.update((l) => [s, ...l.filter((x) => x.id !== s.id)]);
      this.beep();
    }
    if (name === 'sos.updated') {
      this.sosAlerts.update((l) => (data.status === 'Resolved' ? l.filter((x) => x.id !== data.id) : l.map((x) => (x.id === data.id ? data : x))));
    }
    this.events.next({ name, data });
  }

  /** Short alarm tone for new SOS alerts (plays once the admin has interacted with the page). */
  private beep() {
    try {
      const ctx = new AudioContext();
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.type = 'square';
      o.frequency.value = 880;
      g.gain.value = 0.06;
      o.connect(g).connect(ctx.destination);
      o.start();
      o.stop(ctx.currentTime + 0.6);
    } catch { /* audio not allowed yet */ }
  }
}
