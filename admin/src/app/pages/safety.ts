import { Component, OnDestroy, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Subscription } from 'rxjs';
import { AdminApi, errorText } from '../core/api';
import { AgoPipe, PhonePipe } from '../core/format';
import { Sos } from '../core/models';
import { Realtime } from '../core/realtime';

/** SOS alerts: open ones first, with who raised them, where, and their emergency contact. */
@Component({
  selector: 'ftr-safety',
  imports: [FormsModule, DatePipe, RouterLink, AgoPipe, PhonePipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>Safety &amp; SOS</h1><p>Call the person first. Acknowledge so the team knows someone is on it, then resolve with a note.</p></div>
        <div class="tabs">
          <button [class.on]="openOnly" (click)="openOnly = true; load()">Open</button>
          <button [class.on]="!openOnly" (click)="openOnly = false; load()">All</button>
        </div>
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      <div class="alerts">
        @for (s of list(); track s.id) {
          <div class="card alert" [class.open]="s.status === 'Open'" [class.ack]="s.status === 'Acknowledged'">
            <div class="top">
              <span class="pill" [class.red]="s.status === 'Open'" [class.orange]="s.status === 'Acknowledged'" [class.green]="s.status === 'Resolved'">{{ s.status }}</span>
              <span class="small">{{ s.createdAt | date: 'd MMM, HH:mm:ss' }} · {{ s.createdAt | ago }}</span>
            </div>
            <h2>{{ s.raisedByName }} <span class="muted">({{ s.raisedByRole }})</span></h2>
            <dl class="facts">
              <dt>Phone</dt><dd><a [href]="'tel:' + s.raisedByPhone">{{ s.raisedByPhone | phone }}</a></dd>
              <dt>Emergency contact</dt><dd>@if (s.emergencyContact) { <a [href]="'tel:' + s.emergencyContact">{{ s.emergencyContact | phone }}</a> } @else { — }</dd>
              <dt>Ride</dt><dd><a [routerLink]="['/rides']" [queryParams]="{ open: s.rideId }" class="mono">{{ s.rideCode }}</a></dd>
              <dt>Location</dt><dd>@if (s.lat != null) { <a [href]="'https://www.google.com/maps?q=' + s.lat + ',' + s.lng" target="_blank" rel="noopener">{{ s.lat.toFixed(5) }}, {{ s.lng?.toFixed(5) }}</a> } @else { Unknown }</dd>
              @if (s.message) { <dt>Message</dt><dd>{{ s.message }}</dd> }
              @if (s.resolutionNote) { <dt>Resolution</dt><dd>{{ s.resolutionNote }}</dd> }
            </dl>
            @if (s.status !== 'Resolved') {
              <div class="actions">
                @if (s.status === 'Open') { <button class="btn" (click)="update(s, 'Acknowledged')">Acknowledge</button> }
                <input class="input" [(ngModel)]="notes[s.id]" placeholder="What happened? (required to resolve)" />
                <button class="btn green" [disabled]="!notes[s.id]?.trim()" (click)="update(s, 'Resolved')">Resolve</button>
              </div>
            }
          </div>
        } @empty { <div class="card empty">No {{ openOnly ? 'open ' : '' }}SOS alerts. Everyone is safe.</div> }
      </div>
    </div>
  `,
  styles: `
    .alerts { display: grid; gap: 14px; grid-template-columns: repeat(auto-fill, minmax(380px, 1fr)); }
    @media (max-width: 500px) { .alerts { grid-template-columns: 1fr; } }
    .alert { padding: 18px 20px; display: grid; gap: 12px; border-left: 5px solid var(--border); }
    .alert.open { border-left-color: var(--red); }
    .alert.ack { border-left-color: var(--orange); }
    .top { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    .actions { display: flex; gap: 8px; flex-wrap: wrap; }
    .actions .input { flex: 1; min-width: 160px; }
  `,
})
export class SafetyPage implements OnInit, OnDestroy {
  private readonly api = inject(AdminApi);
  private readonly rt = inject(Realtime);
  readonly list = signal<Sos[]>([]);
  readonly error = signal('');
  openOnly = true;
  notes: Record<string, string> = {};
  private sub?: Subscription;

  ngOnInit() {
    this.load();
    this.sub = this.rt.events.subscribe((e) => { if (e.name === 'sos.raised' || e.name === 'sos.updated') this.load(); });
  }

  ngOnDestroy() { this.sub?.unsubscribe(); }

  async load() {
    try {
      const l = await this.api.sos(this.openOnly);
      this.list.set(l);
      if (this.openOnly) this.rt.setOpenSos(l);
      this.error.set('');
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  async update(s: Sos, status: 'Acknowledged' | 'Resolved') {
    try {
      await this.api.updateSos(s.id, status, this.notes[s.id]);
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    }
  }
}
