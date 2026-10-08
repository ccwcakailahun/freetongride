import { Component, OnDestroy, OnInit, inject, signal } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AdminApi, AuthService } from '../core/api';
import { Realtime } from '../core/realtime';
import { InitialsPipe } from '../core/format';
import { Icon } from './icon';

interface NavItem { path: string; label: string; icon: string; badge?: () => number; }

@Component({
  selector: 'ftr-shell',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, Icon, InitialsPipe],
  template: `
    <aside class="side" [class.open]="menuOpen()">
      <a class="brand" routerLink="/dashboard">
        <img src="logo-mark.png" alt="" />
        <span><b>FreeTong<em>Ride</em></b><small>Operations</small></span>
      </a>
      <nav>
        @for (group of groups; track group.title) {
          <p class="group">{{ group.title }}</p>
          @for (item of group.items; track item.path) {
            <a [routerLink]="item.path" routerLinkActive="on" (click)="menuOpen.set(false)">
              <ftr-icon [name]="item.icon" />
              <span>{{ item.label }}</span>
              @if (item.badge && item.badge() > 0) { <i class="badge">{{ item.badge() }}</i> }
            </a>
          }
        }
      </nav>
      <div class="me">
        <a class="me-link" routerLink="/account" (click)="menuOpen.set(false)" title="My account and password">
          <div class="avatar">{{ (auth.user()?.fullName ?? 'A') | initials }}</div>
          <div class="grow"><b>{{ auth.user()?.fullName }}</b><span>My account</span></div>
        </a>
        <button class="icon-btn" title="Sign out" (click)="auth.logout()"><ftr-icon name="logout" /></button>
      </div>
    </aside>

    <div class="main">
      <header class="top">
        <button class="icon-btn menu" (click)="menuOpen.set(!menuOpen())" aria-label="Menu">☰</button>
        <div class="grow"></div>
        <span class="live" [class.on]="rt.connected()">
          <i></i>{{ rt.connected() ? 'Live' : 'Reconnecting…' }}
        </span>
      </header>

      @if (rt.sosAlerts().length > 0) {
        <a class="sos-banner" routerLink="/safety">
          <ftr-icon name="alert" [size]="22" />
          <span>
            <b>{{ rt.sosAlerts().length }} open SOS alert{{ rt.sosAlerts().length > 1 ? 's' : '' }}</b>
            — latest from {{ rt.sosAlerts()[0].raisedByName }} on ride {{ rt.sosAlerts()[0].rideCode }}
          </span>
          <b class="go">Respond now →</b>
        </a>
      }

      <router-outlet />
    </div>
  `,
  styles: `
    :host { display: grid; grid-template-columns: 248px minmax(0, 1fr); min-height: 100vh; }
    .side { background: var(--navy); color: #c9d1ee; display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh; padding: 18px 14px; }
    .brand { display: flex; align-items: center; gap: 10px; padding: 4px 8px 18px; }
    .brand img { width: 38px; height: 42px; object-fit: contain; }
    .brand b { color: #fff; font-size: 19px; font-weight: 800; letter-spacing: -0.03em; display: block; }
    .brand em { font-style: normal; color: #5fe39b; }
    .brand small { color: #8f9bc7; font-size: 11px; letter-spacing: 0.16em; text-transform: uppercase; }
    nav { display: grid; gap: 2px; flex: 1; overflow-y: auto; }
    .group { margin: 14px 10px 6px; font-size: 10.5px; letter-spacing: 0.14em; text-transform: uppercase; color: #6f7cab; font-weight: 700; }
    nav a { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: 12px; color: #c9d1ee; font-weight: 600; font-size: 14px; }
    nav a:hover { background: var(--navy-2); color: #fff; }
    nav a.on { background: linear-gradient(90deg, #2f7bff, var(--blue-deep)); color: #fff; box-shadow: 0 8px 18px rgba(26, 92, 255, 0.3); }
    nav a span { flex: 1; }
    .badge { font-style: normal; background: var(--red); color: #fff; font-size: 11px; font-weight: 800; border-radius: 10px; padding: 1px 7px; }
    .me { display: flex; align-items: center; gap: 10px; padding: 12px 8px 0; border-top: 1px solid #1d2966; }
    .me-link { display: flex; align-items: center; gap: 10px; flex: 1; min-width: 0; color: inherit; font-weight: inherit; border-radius: 10px; padding: 4px; }
    .me-link:hover { background: var(--navy-2); }
    .me .grow { flex: 1; min-width: 0; }
    .me b { color: #fff; display: block; font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .me span { font-size: 11.5px; color: #8f9bc7; }
    .icon-btn { width: 36px; height: 36px; border-radius: 10px; border: 1px solid #26337a; background: transparent; color: inherit; cursor: pointer; display: grid; place-items: center; }
    .main { min-width: 0; }
    .top { display: flex; align-items: center; gap: 12px; padding: 14px 28px 0; }
    .top .grow { flex: 1; }
    .menu { display: none; color: var(--ink); border-color: var(--border); background: #fff; }
    .live { display: inline-flex; align-items: center; gap: 8px; font-weight: 700; font-size: 12.5px; color: var(--muted); background: #fff; border: 1px solid var(--border); padding: 6px 12px; border-radius: 999px; }
    .live i { width: 8px; height: 8px; border-radius: 50%; background: var(--faint); }
    .live.on { color: #0e8d4e; }
    .live.on i { background: var(--green); box-shadow: 0 0 0 4px rgba(25, 184, 104, 0.18); }
    .sos-banner { margin: 14px 28px 0; display: flex; align-items: center; gap: 12px; background: var(--red); color: #fff; padding: 12px 16px; border-radius: 14px; font-weight: 500; box-shadow: 0 10px 24px rgba(229, 72, 77, 0.35); animation: glow 1.6s infinite; }
    .sos-banner span { flex: 1; }
    .sos-banner .go { white-space: nowrap; }
    @keyframes glow { 50% { box-shadow: 0 10px 34px rgba(229, 72, 77, 0.6); } }
    @media (max-width: 900px) {
      :host { grid-template-columns: 1fr; }
      .side { position: fixed; z-index: 30; left: 0; width: 260px; transform: translateX(-100%); transition: transform 0.2s; }
      .side.open { transform: none; }
      .menu { display: grid; }
      .top, .sos-banner { margin-left: 16px; margin-right: 16px; padding-left: 0; padding-right: 0; }
    }
  `,
})
export class Shell implements OnInit, OnDestroy {
  protected readonly auth = inject(AuthService);
  protected readonly rt = inject(Realtime);
  private readonly api = inject(AdminApi);
  protected readonly menuOpen = signal(false);
  private readonly pendingDrivers = signal(0);
  private readonly pendingPayouts = signal(0);
  private timer?: ReturnType<typeof setInterval>;

  protected readonly groups: { title: string; items: NavItem[] }[] = [
    { title: 'Monitor', items: [
      { path: '/dashboard', label: 'Dashboard', icon: 'dashboard' },
      { path: '/live', label: 'Live map', icon: 'map' },
      { path: '/rides', label: 'Rides', icon: 'car' },
      { path: '/safety', label: 'Safety & SOS', icon: 'shield', badge: () => this.rt.sosAlerts().length },
    ] },
    { title: 'People', items: [
      { path: '/drivers', label: 'Drivers', icon: 'driver', badge: () => this.pendingDrivers() },
      { path: '/passengers', label: 'Passengers', icon: 'users' },
    ] },
    { title: 'Money', items: [
      { path: '/payouts', label: 'Driver payouts', icon: 'wallet', badge: () => this.pendingPayouts() },
      { path: '/transactions', label: 'Transactions', icon: 'receipt' },
      { path: '/fares', label: 'Ride types & fares', icon: 'sliders' },
    ] },
  ];

  ngOnInit() {
    this.rt.connect();
    this.api.sos(true).then((l) => this.rt.setOpenSos(l)).catch(() => {});
    this.refreshCounts();
    this.timer = setInterval(() => this.refreshCounts(), 60_000);
    this.rt.events.subscribe((e) => { if (e.name === 'driver.submitted') this.refreshCounts(); });
  }

  ngOnDestroy() {
    clearInterval(this.timer);
    this.rt.disconnect();
  }

  private refreshCounts() {
    this.api.dashboard().then((d) => {
      this.pendingDrivers.set(d.driversPendingReview);
      this.pendingPayouts.set(d.pendingWithdrawals);
    }).catch(() => {});
  }
}
