import { Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminApi, errorText } from '../core/api';
import { AgoPipe, LePipe, PhonePipe } from '../core/format';
import { Paged, PassengerRow } from '../core/models';
import { Avatar, Pager } from './shared';

@Component({
  selector: 'ftr-passengers',
  imports: [FormsModule, DatePipe, LePipe, AgoPipe, PhonePipe, Avatar, Pager],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>Passengers</h1><p>Everyone who rides with FreeTongRide. Suspend an account to stop it booking.</p></div>
        <div class="search"><input class="input" placeholder="Name, phone or email" [(ngModel)]="search" (keyup.enter)="page = 1; load()" /></div>
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      <div class="card">
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Passenger</th><th>Phone</th><th class="right">Rides</th><th class="right">Rating</th><th class="right">Wallet</th><th>Joined</th><th>Last seen</th><th></th></tr></thead>
            <tbody>
              @for (p of data()?.items ?? []; track p.id) {
                <tr>
                  <td><div class="who"><ftr-avatar [name]="p.fullName" [photo]="p.photoUrl" /><div><b>{{ p.fullName }}</b><span>{{ p.email ?? '' }}</span></div></div></td>
                  <td>{{ p.phone | phone }} @if (!p.phoneVerified) { <span class="pill orange" title="Has not entered the SMS code yet, so cannot sign in">Unverified</span> }</td>
                  <td class="right num">{{ p.rides }}</td>
                  <td class="right num">★ {{ p.rating.toFixed(1) }}</td>
                  <td class="right num">{{ p.walletBalance | le }}</td>
                  <td class="small">{{ p.createdAt | date: 'd MMM y' }}</td>
                  <td class="small">{{ p.lastLoginAt | ago }}</td>
                  <td class="right actions">
                    @if (!p.phoneVerified) { <button class="btn sm" (click)="verify(p)" title="Use when the person could not receive the SMS code">Mark phone verified</button> }
                    @if (p.isActive) { <button class="btn sm ghost-danger" (click)="toggle(p)">Suspend</button> }
                    @else { <button class="btn sm green" (click)="toggle(p)">Reactivate</button> }
                  </td>
                </tr>
              } @empty { <tr><td colspan="8" class="empty">No passengers found.</td></tr> }
            </tbody>
          </table>
        </div>
        @if (data(); as d) { <ftr-pager [page]="page" [pageSize]="20" [total]="d.total" (go)="page = $event; load()" /> }
      </div>
    </div>
  `,
  styles: `.actions { white-space: nowrap; } .actions .btn + .btn { margin-left: 6px; }`,
})
export class PassengersPage implements OnInit {
  // Passengers who could not get the SMS code can be verified by hand until an SMS provider is connected.
  private readonly api = inject(AdminApi);
  readonly data = signal<Paged<PassengerRow> | null>(null);
  readonly error = signal('');
  search = '';
  page = 1;

  ngOnInit() { this.load(); }

  async load() {
    try {
      this.data.set(await this.api.passengers({ search: this.search, page: this.page, pageSize: 20 }));
      this.error.set('');
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  async verify(p: PassengerRow) {
    try {
      await this.api.verifyPhone(p.id);
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  async toggle(p: PassengerRow) {
    try {
      await this.api.setActive(p.id, !p.isActive);
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    }
  }
}
