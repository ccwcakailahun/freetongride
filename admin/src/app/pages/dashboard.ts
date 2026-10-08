import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Subscription } from 'rxjs';
import { AdminApi, errorText } from '../core/api';
import { AgoPipe, CountPipe, LePipe } from '../core/format';
import { Dashboard, Ride } from '../core/models';
import { Realtime } from '../core/realtime';
import { Icon } from '../layout/icon';
import { Avatar, RideStatusPill } from './shared';

@Component({
  selector: 'ftr-dashboard',
  imports: [RouterLink, LePipe, AgoPipe, CountPipe, Icon, RideStatusPill, Avatar],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow">
          <h1>Good {{ partOfDay }}, here is Freetown right now</h1>
          <p>Today's rides, money and anything that needs your attention. Updates live.</p>
        </div>
        <button class="btn" (click)="load()"><ftr-icon name="refresh" [size]="16" /> Refresh</button>
      </div>

      @if (error()) { <div class="error-box">{{ error() }}</div> }

      @if (d(); as d) {
        <!-- Needs attention first -->
        <div class="grid kpis">
          <a class="card kpi" [class.alert]="d.openSos > 0" routerLink="/safety">
            <span class="label">Open SOS</span><span class="value">{{ d.openSos }}</span>
            <span class="sub">{{ d.openSos ? 'Respond now' : 'All clear' }}</span>
            <span class="icon" style="background:var(--red-soft);color:var(--red)"><ftr-icon name="alert" /></span>
          </a>
          <a class="card kpi" routerLink="/drivers" [queryParams]="{ status: 'UnderReview' }">
            <span class="label">Drivers to review</span><span class="value">{{ d.driversPendingReview }}</span>
            <span class="sub">Documents waiting</span>
            <span class="icon" style="background:var(--orange-soft);color:var(--orange)"><ftr-icon name="driver" /></span>
          </a>
          <a class="card kpi" routerLink="/payouts">
            <span class="label">Payouts pending</span><span class="value">{{ d.pendingWithdrawals }}</span>
            <span class="sub">{{ d.pendingWithdrawalAmount | le }} requested</span>
            <span class="icon" style="background:var(--purple-soft);color:var(--purple)"><ftr-icon name="wallet" /></span>
          </a>
          <a class="card kpi" routerLink="/live">
            <span class="label">Drivers online</span><span class="value">{{ d.driversOnline | count }}</span>
            <span class="sub">{{ d.activeRides }} on a trip · {{ d.searchingRides }} {{ d.searchingRides === 1 ? 'request' : 'requests' }} open</span>
            <span class="icon" style="background:var(--green-soft);color:var(--green)"><ftr-icon name="bolt" /></span>
          </a>
        </div>

        <div class="grid kpis">
          <div class="card kpi"><span class="label">Rides today</span><span class="value">{{ d.ridesToday | count }}</span>
            <span class="sub">{{ d.completedToday }} completed · {{ d.cancelledToday }} cancelled</span></div>
          <div class="card kpi"><span class="label">Fares today</span><span class="value">{{ d.gmvToday | le }}</span><span class="sub">Completed trips</span></div>
          <div class="card kpi"><span class="label">Commission today</span><span class="value" style="color:var(--green)">{{ d.commissionToday | le }}</span><span class="sub">Platform revenue</span></div>
          <div class="card kpi"><span class="label">Passengers</span><span class="value">{{ d.passengersTotal | count }}</span><span class="sub">+{{ d.newPassengersToday | count }} today · {{ d.driversTotal | count }} drivers</span></div>
        </div>

        <div class="grid two">
          <div class="card">
            <div class="card-head"><h2>Rides, last 14 days</h2><span class="small">Bar = rides · line = fares</span></div>
            <div class="chart">
              <svg [attr.viewBox]="'0 0 ' + W + ' ' + H" preserveAspectRatio="none" role="img" aria-label="Rides per day for the last 14 days">
                @for (t of ticks(); track t) {
                  <line [attr.x1]="40" [attr.x2]="W - 10" [attr.y1]="y(t)" [attr.y2]="y(t)" class="grid-line" />
                  <text [attr.x]="34" [attr.y]="y(t) + 4" text-anchor="end" class="axis">{{ t }}</text>
                }
                @for (p of d.last14Days; track p.day; let i = $index) {
                  <rect [attr.x]="x(i) - bw / 2" [attr.y]="y(p.rides)" [attr.width]="bw" [attr.height]="H - 28 - y(p.rides)" rx="5" class="bar" [class.today]="i === 13">
                    <title>{{ p.day }}: {{ p.rides }} rides, {{ p.gmv | le }}</title>
                  </rect>
                  @if (i % 2 === 1 || i === 13) { <text [attr.x]="x(i)" [attr.y]="H - 8" text-anchor="middle" class="axis">{{ label(p.day) }}</text> }
                }
                <polyline [attr.points]="gmvLine()" class="line" />
                @if (d.last14Days.length) { <circle [attr.cx]="x(13)" [attr.cy]="gy(d.last14Days[13].gmv)" r="4.5" class="dot" /> }
              </svg>
            </div>
          </div>
          <div class="card">
            <div class="card-head"><h2>Today by ride type</h2></div>
            <div class="split">
              @for (s of d.serviceSplitToday; track s.service) {
                <div class="split-row">
                  <span class="name">{{ s.service }}</span>
                  <span class="track"><i [style.width.%]="(100 * s.rides) / maxSplit()"></i></span>
                  <b class="num">{{ s.rides }}</b>
                </div>
              } @empty { <p class="empty">No rides yet today.</p> }
            </div>
          </div>
        </div>
      }

      <div class="card">
        <div class="card-head"><h2>Rides happening now</h2><a routerLink="/live">Open live map →</a></div>
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Ride</th><th>Status</th><th>Passenger</th><th>Driver</th><th>Route</th><th class="right">Fare</th></tr></thead>
            <tbody>
              @for (r of active(); track r.id) {
                <tr class="click" [routerLink]="['/rides']" [queryParams]="{ open: r.id }">
                  <td><b class="mono">{{ r.code }}</b><div class="small">{{ r.createdAt | ago }}</div></td>
                  <td><ftr-ride-status [status]="r.status" /></td>
                  <td><div class="who"><ftr-avatar [name]="r.passenger.fullName" [photo]="r.passenger.photoUrl" /><div><b>{{ r.passenger.fullName }}</b></div></div></td>
                  <td>@if (r.driver) { <div class="who"><ftr-avatar [name]="r.driver.fullName" [photo]="r.driver.photoUrl" /><div><b>{{ r.driver.fullName }}</b><span>{{ r.driver.plateNumber }}</span></div></div> } @else { <span class="muted">Waiting for offers</span> }</td>
                  <td><div class="route"><div><i></i>{{ r.pickup.address }}</div><div><i></i>{{ r.dropoff.address }}</div></div></td>
                  <td class="right num"><b>{{ r.fareDue | le }}</b><div class="small">{{ r.serviceName }} · {{ r.paymentMethod }}</div></td>
                </tr>
              } @empty { <tr><td colspan="6" class="empty">No rides in progress right now.</td></tr> }
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `,
  styles: `
    a.card { color: inherit; font-weight: inherit; }
    .chart { padding: 10px 14px 4px; }
    svg { width: 100%; height: 240px; display: block; }
    .grid-line { stroke: var(--border); stroke-width: 1; }
    .axis { fill: var(--muted); font-size: 11px; font-family: var(--font); }
    .bar { fill: #c9dafe; }
    .bar.today { fill: var(--blue); }
    .line { fill: none; stroke: var(--green); stroke-width: 2.5; stroke-linejoin: round; }
    .dot { fill: #fff; stroke: var(--green); stroke-width: 3; }
    .split { padding: 16px 20px; display: grid; gap: 14px; }
    .split-row { display: grid; grid-template-columns: 70px 1fr 36px; align-items: center; gap: 12px; }
    .split-row .name { font-weight: 700; color: var(--ink); }
    .track { height: 10px; background: #eef2fa; border-radius: 6px; overflow: hidden; }
    .track i { display: block; height: 100%; background: linear-gradient(90deg, #22d36f, var(--blue)); border-radius: 6px; }
    .split-row b { text-align: right; color: var(--ink); }
  `,
})
export class DashboardPage implements OnInit, OnDestroy {
  private readonly api = inject(AdminApi);
  private readonly rt = inject(Realtime);
  readonly d = signal<Dashboard | null>(null);
  readonly active = signal<Ride[]>([]);
  readonly error = signal('');
  private sub?: Subscription;
  private reloadTimer?: ReturnType<typeof setTimeout>;
  readonly partOfDay = new Date().getHours() < 12 ? 'morning' : new Date().getHours() < 17 ? 'afternoon' : 'evening';

  readonly W = 640;
  readonly H = 240;
  readonly bw = 22;

  readonly maxRides = computed(() => Math.max(4, ...(this.d()?.last14Days.map((p) => p.rides) ?? [0])));
  readonly maxGmv = computed(() => Math.max(1, ...(this.d()?.last14Days.map((p) => p.gmv) ?? [0])));
  readonly maxSplit = computed(() => Math.max(1, ...(this.d()?.serviceSplitToday.map((s) => s.rides) ?? [0])));
  readonly ticks = computed(() => {
    const m = this.maxRides();
    const step = Math.max(1, Math.ceil(m / 4));
    return [0, step, step * 2, step * 3, step * 4];
  });
  readonly gmvLine = computed(() => (this.d()?.last14Days ?? []).map((p, i) => `${this.x(i)},${this.gy(p.gmv)}`).join(' '));

  x(i: number) { return 40 + 18 + i * ((this.W - 40 - 36) / 13); }
  y(v: number) { const top = this.ticks()[4]; return 12 + (1 - v / top) * (this.H - 40); }
  gy(v: number) { return 12 + (1 - v / this.maxGmv()) * (this.H - 40); }
  label(day: string) { return new Date(day).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' }); }

  ngOnInit() {
    this.load();
    this.sub = this.rt.events.subscribe((e) => {
      if (e.name === 'ride.updated' || e.name === 'sos.raised') {
        clearTimeout(this.reloadTimer);
        this.reloadTimer = setTimeout(() => this.load(), 800);
      }
    });
  }

  ngOnDestroy() {
    this.sub?.unsubscribe();
    clearTimeout(this.reloadTimer);
  }

  async load() {
    try {
      const [d, live] = await Promise.all([this.api.dashboard(), this.api.live()]);
      this.d.set(d);
      this.active.set(live.activeRides);
      this.error.set('');
    } catch (e) {
      this.error.set(errorText(e));
    }
  }
}
