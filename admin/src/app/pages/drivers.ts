import { Component, OnInit, inject, input, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminApi, absolute, errorText } from '../core/api';
import { AgoPipe, LePipe, PhonePipe } from '../core/format';
import { DriverDetail, DriverRow, DriverStatus, Paged } from '../core/models';
import { Avatar, DriverStatusPill, Pager, RideStatusPill } from './shared';

const DOC_LABEL: Record<string, string> = {
  DrivingLicence: 'Driving licence', NationalId: 'National ID', ProfilePhoto: 'Profile photo',
  VehiclePhoto: 'Vehicle photo', VehicleRegistration: 'Registration', Insurance: 'Insurance',
};

@Component({
  selector: 'ftr-drivers',
  imports: [FormsModule, DatePipe, LePipe, AgoPipe, PhonePipe, Avatar, Pager, DriverStatusPill, RideStatusPill],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>Drivers</h1><p>Review new drivers, check documents and vehicles, and manage who can drive.</p></div>
        <div class="search"><input class="input" placeholder="Name, phone or plate" [(ngModel)]="search" (keyup.enter)="reload()" /></div>
      </div>
      <div class="tabs">
        @for (t of tabs; track t.value) {
          <button [class.on]="status === t.value" (click)="status = t.value; reload()">{{ t.label }}</button>
        }
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      <div class="card">
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Driver</th><th>Status</th><th>Vehicle</th><th>Online</th><th class="right">Trips</th><th class="right">Rating</th><th class="right">Wallet</th><th>Joined</th></tr></thead>
            <tbody>
              @for (d of data()?.items ?? []; track d.id) {
                <tr class="click" (click)="open(d.id)">
                  <td><div class="who"><ftr-avatar [name]="d.fullName" [photo]="d.photoUrl" /><div><b>{{ d.fullName }}</b><span>{{ d.phone | phone }}</span></div></div></td>
                  <td><ftr-driver-status [status]="d.status" /></td>
                  <td>@if (!d.phoneVerified) { <span class="pill orange" style="margin-bottom:4px">Phone unverified</span> }<b>{{ d.serviceName ?? '—' }}</b><div class="small">{{ d.vehicle || 'No vehicle yet' }}</div></td>
                  <td>@if (d.isOnline) { <span class="pill green">Online</span> } @else { <span class="small">{{ d.lastSeenAt | ago }}</span> }</td>
                  <td class="right num">{{ d.completedTrips }}</td>
                  <td class="right num">★ {{ d.rating.toFixed(1) }}</td>
                  <td class="right num" [style.color]="d.walletBalance < 0 ? 'var(--red)' : null">{{ d.walletBalance | le }}</td>
                  <td class="small">{{ d.createdAt | date: 'd MMM y' }}</td>
                </tr>
              } @empty { <tr><td colspan="8" class="empty">{{ loading() ? 'Loading…' : 'No drivers here.' }}</td></tr> }
            </tbody>
          </table>
        </div>
        @if (data(); as d) { <ftr-pager [page]="page" [pageSize]="20" [total]="d.total" (go)="page = $event; load()" /> }
      </div>
    </div>

    @if (detail(); as det) {
      <div class="scrim" (click)="detail.set(null)"></div>
      <aside class="drawer" role="dialog" aria-label="Driver details">
        <div class="drawer-head">
          <ftr-avatar [name]="det.driver.fullName" [photo]="det.driver.photoUrl" [large]="true" />
          <div style="flex:1;min-width:0"><h2>{{ det.driver.fullName }}</h2><span class="small">{{ det.driver.phone | phone }} · ★ {{ det.driver.rating.toFixed(1) }} ({{ det.driver.ratingCount }})</span></div>
          <ftr-driver-status [status]="det.driver.status" />
          <button class="close" (click)="detail.set(null)" aria-label="Close">×</button>
        </div>
        <div class="drawer-body">
          @if (!det.driver.phoneVerified) {
            <div class="card pad verify">
              <div><b>Phone not verified.</b> <span class="muted">This driver has not entered the SMS code, so they cannot sign in.</span></div>
              <button class="btn" [disabled]="busy()" (click)="verifyPhone(det)">Mark phone verified</button>
            </div>
          }
          @if (det.profile.rejectReason) { <div class="error-box">Last rejection: {{ det.profile.rejectReason }}</div> }
          <div class="card pad">
            <h3>Vehicle</h3>
            <dl class="facts" style="margin-top:10px">
              <dt>Ride type</dt><dd>{{ det.profile.serviceName ?? '—' }}</dd>
              <dt>Vehicle</dt><dd>{{ det.profile.vehicleMake }} {{ det.profile.vehicleModel }} · {{ det.profile.vehicleColor }} · {{ det.profile.vehicleYear }}</dd>
              <dt>Plate</dt><dd class="mono">{{ det.profile.plateNumber ?? '—' }}</dd>
              <dt>Licence no.</dt><dd class="mono">{{ det.profile.licenceNumber || '—' }}</dd>
              <dt>Trips</dt><dd>{{ det.driver.completedTrips }}</dd>
              <dt>Wallet</dt><dd>{{ det.driver.walletBalance | le }}</dd>
            </dl>
          </div>
          <div class="card pad">
            <h3>Documents</h3>
            @if (det.profile.missingDocuments.length) { <p class="small">Missing: {{ missing(det) }}</p> }
            <div class="docs">
              @for (doc of det.profile.documents; track doc.id) {
                <a class="doc" [href]="url(doc.fileUrl)" target="_blank" rel="noopener">
                  @if (!doc.fileUrl.endsWith('.pdf')) { <img [src]="url(doc.fileUrl)" alt="" loading="lazy" /> } @else { <span class="pdf">PDF</span> }
                  <span>{{ label(doc.type) }}</span>
                </a>
              } @empty { <p class="empty">No documents uploaded.</p> }
            </div>
          </div>
          @if (det.driver.status === 'UnderReview' || det.driver.status === 'Rejected' || det.driver.status === 'PendingDocuments') {
            <div class="card pad decide">
              <h3>Decision</h3>
              <textarea class="input" rows="2" [(ngModel)]="reason" placeholder="Reason if rejecting, e.g. Licence photo is blurry"></textarea>
              <div class="row">
                <button class="btn ghost-danger" [disabled]="busy() || !reason.trim()" (click)="review(det, false)">Reject</button>
                <button class="btn green" [disabled]="busy() || det.profile.missingDocuments.length > 0" (click)="review(det, true)">Approve driver</button>
              </div>
            </div>
          }
          @if (det.driver.status === 'Approved') {
            <button class="btn ghost-danger" [disabled]="busy()" (click)="suspend(det, true)">Suspend driver</button>
          }
          @if (det.driver.status === 'Suspended') {
            <button class="btn green" [disabled]="busy()" (click)="suspend(det, false)">Reinstate driver</button>
          }
          <div class="card">
            <div class="card-head"><h2>Recent trips</h2></div>
            @for (r of det.recentRides; track r.id) {
              <div class="line"><span class="mono">{{ r.code }}</span><span class="grow">{{ r.pickup.address }} → {{ r.dropoff.address }}</span><ftr-ride-status [status]="r.status" /><b class="num">{{ r.fareDue | le }}</b></div>
            } @empty { <p class="empty">No trips yet.</p> }
          </div>
        </div>
      </aside>
    }
  `,
  styles: `
    .docs { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 12px; margin-top: 12px; }
    .doc { display: grid; gap: 6px; color: var(--ink); font-size: 12.5px; }
    .doc img, .doc .pdf { width: 100%; aspect-ratio: 4 / 3; object-fit: cover; border-radius: 12px; border: 1px solid var(--border); background: #f1f4fa; display: grid; place-items: center; font-weight: 800; color: var(--muted); }
    .decide { display: grid; gap: 10px; }
    .verify { display: flex; gap: 12px; align-items: center; justify-content: space-between; border-left: 4px solid var(--orange); }
    .decide .row { display: flex; gap: 10px; justify-content: flex-end; }
    .line { display: flex; align-items: center; gap: 12px; padding: 12px 20px; border-bottom: 1px solid var(--border); }
    .line .grow { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  `,
})
export class DriversPage implements OnInit {
  private readonly api = inject(AdminApi);
  /** ?status=UnderReview from the dashboard. */
  readonly statusParam = input<DriverStatus | undefined>(undefined, { alias: 'status' });
  readonly data = signal<Paged<DriverRow> | null>(null);
  readonly detail = signal<DriverDetail | null>(null);
  readonly loading = signal(false);
  readonly busy = signal(false);
  readonly error = signal('');
  status: DriverStatus | '' = '';
  search = '';
  page = 1;
  reason = '';

  readonly tabs: { label: string; value: DriverStatus | '' }[] = [
    { label: 'All', value: '' },
    { label: 'Needs review', value: 'UnderReview' },
    { label: 'Approved', value: 'Approved' },
    { label: 'Incomplete', value: 'PendingDocuments' },
    { label: 'Rejected', value: 'Rejected' },
    { label: 'Suspended', value: 'Suspended' },
  ];

  ngOnInit() {
    this.status = this.statusParam() ?? '';
    this.load();
  }

  reload() { this.page = 1; this.load(); }

  async load() {
    this.loading.set(true);
    try {
      this.data.set(await this.api.drivers({ status: this.status, search: this.search, page: this.page, pageSize: 20 }));
      this.error.set('');
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.loading.set(false);
    }
  }

  async open(id: string) {
    try {
      this.detail.set(await this.api.driver(id));
      this.reason = '';
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  async review(det: DriverDetail, approve: boolean) {
    this.busy.set(true);
    try {
      this.detail.set(await this.api.reviewDriver(det.driver.id, approve, approve ? undefined : this.reason.trim()));
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.busy.set(false);
    }
  }

  async verifyPhone(det: DriverDetail) {
    this.busy.set(true);
    try {
      await this.api.verifyPhone(det.driver.id);
      await this.open(det.driver.id);
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.busy.set(false);
    }
  }

  async suspend(det: DriverDetail, suspended: boolean) {
    this.busy.set(true);
    try {
      await this.api.suspendDriver(det.driver.id, suspended);
      await this.open(det.driver.id);
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.busy.set(false);
    }
  }

  url(p: string) { return absolute(p) ?? ''; }
  label(t: string) { return DOC_LABEL[t] ?? t; }
  missing(det: DriverDetail) { return det.profile.missingDocuments.map((m) => DOC_LABEL[m] ?? m).join(', '); }
}
