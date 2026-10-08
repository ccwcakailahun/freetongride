import { Component, OnDestroy, OnInit, inject, input, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';
import { AdminApi, errorText } from '../core/api';
import { AgoPipe, LePipe, PhonePipe } from '../core/format';
import { Paged, Ride, RideDetail, RideStatus } from '../core/models';
import { Realtime } from '../core/realtime';
import { Avatar, Pager, RideStatusPill } from './shared';

@Component({
  selector: 'ftr-rides',
  imports: [FormsModule, DatePipe, LePipe, AgoPipe, PhonePipe, Avatar, Pager, RideStatusPill],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>Rides</h1><p>Every trip with its offers, chat and payment. Click a row for details.</p></div>
        <div class="search"><input class="input" placeholder="Code, name, phone or place" [(ngModel)]="search" (keyup.enter)="reload()" /></div>
        <input class="input" type="date" [(ngModel)]="from" (change)="reload()" title="From date" />
        <input class="input" type="date" [(ngModel)]="to" (change)="reload()" title="To date" />
      </div>
      <div class="tabs">
        @for (t of statusTabs; track t.value) {
          <button [class.on]="status === t.value" (click)="status = t.value; reload()">{{ t.label }}</button>
        }
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      <div class="card">
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Ride</th><th>Status</th><th>Passenger</th><th>Driver</th><th>Route</th><th class="right">Fare</th><th class="right">Commission</th></tr></thead>
            <tbody>
              @for (r of data()?.items ?? []; track r.id) {
                <tr class="click" (click)="open(r.id)">
                  <td><b class="mono">{{ r.code }}</b><div class="small">{{ r.createdAt | date: 'd MMM, HH:mm' }}</div></td>
                  <td><ftr-ride-status [status]="r.status" /></td>
                  <td><div class="who"><ftr-avatar [name]="r.passenger.fullName" [photo]="r.passenger.photoUrl" /><div><b>{{ r.passenger.fullName }}</b><span>{{ r.passenger.phone | phone }}</span></div></div></td>
                  <td>@if (r.driver) { <div class="who"><ftr-avatar [name]="r.driver.fullName" [photo]="r.driver.photoUrl" /><div><b>{{ r.driver.fullName }}</b><span>{{ r.driver.plateNumber }}</span></div></div> } @else { <span class="muted">—</span> }</td>
                  <td><div class="route"><div><i></i>{{ r.pickup.address }}</div><div><i></i>{{ r.dropoff.address }}</div></div></td>
                  <td class="right num"><b>{{ r.fareDue | le }}</b><div class="small">{{ r.serviceName }} · {{ r.paymentMethod }}</div></td>
                  <td class="right num">{{ r.commission ? (r.commission | le) : '—' }}</td>
                </tr>
              } @empty { <tr><td colspan="7" class="empty">{{ loading() ? 'Loading…' : 'No rides match these filters.' }}</td></tr> }
            </tbody>
          </table>
        </div>
        @if (data(); as d) { <ftr-pager [page]="page" [pageSize]="pageSize" [total]="d.total" (go)="page = $event; load()" /> }
      </div>
    </div>

    @if (detail(); as det) {
      <div class="scrim" (click)="detail.set(null)"></div>
      <aside class="drawer" role="dialog" aria-label="Ride details">
        <div class="drawer-head">
          <h2 class="mono">{{ det.ride.code }}</h2>
          <ftr-ride-status [status]="det.ride.status" />
          <button class="close" (click)="detail.set(null)" aria-label="Close">×</button>
        </div>
        <div class="drawer-body">
          @if (det.sos.length) {
            <div class="error-box">SOS raised {{ det.sos[0].createdAt | ago }} by {{ det.sos[0].raisedByName }} ({{ det.sos[0].status }})</div>
          }
          <div class="card pad">
            <div class="route big"><div><i></i>{{ det.ride.pickup.address }}</div><div><i></i>{{ det.ride.dropoff.address }}</div></div>
            <dl class="facts" style="margin-top:14px">
              <dt>Ride type</dt><dd>{{ det.ride.serviceName }} · {{ det.ride.distanceKm }} km · ~{{ det.ride.durationMinutes }} min</dd>
              <dt>Estimate / offer</dt><dd>{{ det.ride.estimatedFare | le }} / {{ det.ride.offeredFare | le }}</dd>
              <dt>Agreed fare</dt><dd>{{ det.ride.agreedFare ? (det.ride.agreedFare | le) : '—' }}</dd>
              @if (det.ride.discount) { <dt>Discount</dt><dd>- {{ det.ride.discount | le }}</dd> }
              @if (det.ride.tip) { <dt>Tip</dt><dd>{{ det.ride.tip | le }}</dd> }
              <dt>Payment</dt><dd>{{ det.ride.paymentMethod }} · {{ det.ride.paymentStatus }}</dd>
              <dt>Commission</dt><dd>{{ det.ride.commission ? (det.ride.commission | le) : '—' }}</dd>
              @if (det.ride.cancelReason) { <dt>Cancelled</dt><dd>{{ det.ride.cancelledBy }}: {{ det.ride.cancelReason }}</dd> }
            </dl>
          </div>
          <div class="card pad people">
            <div class="who"><ftr-avatar [name]="det.ride.passenger.fullName" [photo]="det.ride.passenger.photoUrl" /><div><b>{{ det.ride.passenger.fullName }}</b><span>Passenger · {{ det.ride.passenger.phone | phone }}</span></div></div>
            @if (det.ride.driver; as dr) {
              <div class="who"><ftr-avatar [name]="dr.fullName" [photo]="dr.photoUrl" /><div><b>{{ dr.fullName }}</b><span>Driver · {{ dr.phone | phone }} · {{ dr.vehicle }}</span></div></div>
            }
          </div>
          <div class="card pad">
            <h3>Timeline</h3>
            <ol class="timeline">
              <li>Requested <span>{{ det.ride.createdAt | date: 'HH:mm:ss' }}</span></li>
              @if (det.ride.assignedAt) { <li>Driver accepted <span>{{ det.ride.assignedAt | date: 'HH:mm:ss' }}</span></li> }
              @if (det.ride.arrivedAt) { <li>Driver arrived <span>{{ det.ride.arrivedAt | date: 'HH:mm:ss' }}</span></li> }
              @if (det.ride.startedAt) { <li>Trip started (code checked) <span>{{ det.ride.startedAt | date: 'HH:mm:ss' }}</span></li> }
              @if (det.ride.endedAt) { <li>Trip ended <span>{{ det.ride.endedAt | date: 'HH:mm:ss' }}</span></li> }
              @if (det.ride.completedAt) { <li>Paid &amp; completed <span>{{ det.ride.completedAt | date: 'HH:mm:ss' }}</span></li> }
              @if (det.ride.cancelledAt) { <li class="bad">Cancelled <span>{{ det.ride.cancelledAt | date: 'HH:mm:ss' }}</span></li> }
            </ol>
          </div>
          <div class="card">
            <div class="card-head"><h2>Driver offers ({{ det.bids.length }})</h2></div>
            @for (b of det.bids; track b.id) {
              <div class="line"><span>{{ b.driver.fullName }} · {{ b.etaMinutes }} min away</span><b class="num">{{ b.amount | le }}</b><span class="pill" [class.green]="b.status === 'Accepted'" [class.grey]="b.status !== 'Accepted'">{{ b.status }}</span></div>
            } @empty { <p class="empty">No offers.</p> }
          </div>
          @if (det.messages.length) {
            <div class="card">
              <div class="card-head"><h2>Chat</h2></div>
              @for (m of det.messages; track m.id) {
                <div class="line"><span><b>{{ m.senderId === det.ride.passenger.id ? 'Passenger' : 'Driver' }}:</b> {{ m.text }}</span><span class="small">{{ m.createdAt | date: 'HH:mm' }}</span></div>
              }
            </div>
          }
          @if (canCancel(det.ride)) {
            <div class="card pad cancel">
              <h3>Cancel this ride</h3>
              <input class="input" [(ngModel)]="cancelReason" placeholder="Reason shown to both people" />
              <button class="btn danger" [disabled]="!cancelReason.trim() || busy()" (click)="cancel(det.ride)">Cancel ride</button>
            </div>
          }
        </div>
      </aside>
    }
  `,
  styles: `
    .route.big { font-size: 15px; font-weight: 700; color: var(--ink); gap: 6px; }
    .people { display: grid; gap: 14px; }
    .timeline { margin: 12px 0 0; padding-left: 18px; display: grid; gap: 8px; }
    .timeline li { color: var(--ink); font-weight: 600; }
    .timeline li span { color: var(--muted); font-weight: 500; margin-left: 8px; font-variant-numeric: tabular-nums; }
    .timeline li.bad { color: var(--red); }
    .line { display: flex; align-items: center; gap: 12px; padding: 12px 20px; border-bottom: 1px solid var(--border); }
    .line span:first-child { flex: 1; }
    .cancel { display: grid; gap: 10px; }
  `,
})
export class RidesPage implements OnInit, OnDestroy {
  private readonly api = inject(AdminApi);
  private readonly rt = inject(Realtime);
  /** ?open=<rideId> opens a ride's drawer directly (links from the dashboard). */
  readonly openId = input<string | undefined>(undefined, { alias: 'open' });
  readonly data = signal<Paged<Ride> | null>(null);
  readonly detail = signal<RideDetail | null>(null);
  readonly loading = signal(false);
  readonly busy = signal(false);
  readonly error = signal('');
  status: RideStatus | '' = '';
  search = '';
  from = '';
  to = '';
  page = 1;
  readonly pageSize = 20;
  cancelReason = '';
  private sub?: Subscription;

  readonly statusTabs: { label: string; value: RideStatus | '' }[] = [
    { label: 'All', value: '' },
    { label: 'Finding driver', value: 'Searching' },
    { label: 'Driver on the way', value: 'DriverAssigned' },
    { label: 'On trip', value: 'InProgress' },
    { label: 'Awaiting payment', value: 'AwaitingPayment' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Cancelled', value: 'Cancelled' },
  ];

  ngOnInit() {
    this.load();
    const id = this.openId();
    if (id) this.open(id);
    this.sub = this.rt.events.subscribe((e) => {
      if (e.name !== 'ride.updated') return;
      const r = e.data as Ride;
      const list = this.data();
      if (list && list.items.some((x) => x.id === r.id)) this.data.set({ ...list, items: list.items.map((x) => (x.id === r.id ? r : x)) });
      else if (this.page === 1 && !this.search && (!this.status || this.status === r.status)) this.load();
      if (this.detail()?.ride.id === r.id) this.open(r.id);
    });
  }

  ngOnDestroy() { this.sub?.unsubscribe(); }

  reload() { this.page = 1; this.load(); }

  async load() {
    this.loading.set(true);
    try {
      this.data.set(await this.api.rides({ status: this.status, search: this.search, from: this.from, to: this.to, page: this.page, pageSize: this.pageSize }));
      this.error.set('');
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.loading.set(false);
    }
  }

  async open(id: string) {
    try {
      this.detail.set(await this.api.ride(id));
      this.cancelReason = '';
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  canCancel(r: Ride) { return r.status !== 'Completed' && r.status !== 'Cancelled'; }

  async cancel(r: Ride) {
    this.busy.set(true);
    try {
      await this.api.cancelRide(r.id, this.cancelReason.trim());
      await this.open(r.id);
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.busy.set(false);
    }
  }
}
