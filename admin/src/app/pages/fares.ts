import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdminApi, errorText } from '../core/api';
import { LePipe } from '../core/format';
import { Service } from '../core/models';

/** Ride types and their fares. A live example shows what a typical trip costs with the values being edited. */
@Component({
  selector: 'ftr-fares',
  imports: [FormsModule, LePipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>Ride types &amp; fares</h1><p>Fare = base + per km + per minute, never below the minimum. Changes apply to new requests immediately.</p></div>
        <label class="field">Example trip
          <span class="example">
            <input class="input" type="number" min="0.5" step="0.5" [(ngModel)]="km" /> km
            <input class="input" type="number" min="1" [(ngModel)]="min" /> min
          </span>
        </label>
        <button class="btn" (click)="add()">Add ride type</button>
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      @if (saved()) { <div class="toast">{{ saved() }}</div> }
      <div class="services">
        @for (s of list(); track s.id ?? $index) {
          <form class="card pad svc" (ngSubmit)="save(s)">
            <div class="head">
              <input class="input name" name="name" [(ngModel)]="s.name" required aria-label="Name" />
              <label class="toggle"><input type="checkbox" name="active" [(ngModel)]="s.isActive" /> Active</label>
            </div>
            <input class="input" name="desc" [(ngModel)]="s.description" placeholder="Short description shown to passengers" />
            <div class="fields">
              <label class="field">Base fare (Le)<input class="input" type="number" min="0" step="0.5" name="base" [(ngModel)]="s.baseFare" /></label>
              <label class="field">Per km (Le)<input class="input" type="number" min="0" step="0.5" name="km" [(ngModel)]="s.perKm" /></label>
              <label class="field">Per minute (Le)<input class="input" type="number" min="0" step="0.1" name="min" [(ngModel)]="s.perMinute" /></label>
              <label class="field">Minimum (Le)<input class="input" type="number" min="0" name="minimum" [(ngModel)]="s.minimumFare" /></label>
              <label class="field">Commission %<input class="input" type="number" min="0" max="50" step="0.5" name="comm" [(ngModel)]="s.commissionPercent" /></label>
              <label class="field">Seats<input class="input" type="number" min="1" max="8" name="seats" [(ngModel)]="s.seats" /></label>
            </div>
            <div class="foot">
              <div>
                <span class="small">{{ km }} km, {{ min }} min trip</span>
                <div class="price">{{ fare(s) | le }}</div>
                <span class="small">Driver keeps {{ fare(s) - commission(s) | le }} · platform {{ commission(s) | le }}</span>
              </div>
              <button class="btn primary" [disabled]="busy()">Save</button>
            </div>
          </form>
        }
      </div>
    </div>
  `,
  styles: `
    .example { display: flex; align-items: center; gap: 6px; color: var(--muted); }
    .example .input { width: 76px; }
    .services { display: grid; gap: 16px; grid-template-columns: repeat(auto-fill, minmax(360px, 1fr)); }
    @media (max-width: 500px) { .services { grid-template-columns: 1fr; } }
    .svc { display: grid; gap: 12px; }
    .head { display: flex; align-items: center; gap: 12px; }
    .name { font-size: 17px; font-weight: 800; flex: 1; }
    .toggle { display: flex; gap: 6px; align-items: center; font-weight: 700; color: var(--ink); }
    .fields { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
    .fields .input { width: 100%; }
    .foot { display: flex; align-items: flex-end; justify-content: space-between; gap: 12px; border-top: 1px solid var(--border); padding-top: 12px; }
    .price { font-size: 26px; font-weight: 800; color: var(--ink); font-variant-numeric: tabular-nums; }
  `,
})
export class FaresPage implements OnInit {
  private readonly api = inject(AdminApi);
  readonly list = signal<(Omit<Service, 'id'> & { id?: string })[]>([]);
  readonly error = signal('');
  readonly saved = signal('');
  readonly busy = signal(false);
  km = 8;
  min = 18;

  ngOnInit() { this.load(); }

  async load() {
    try {
      this.list.set(await this.api.services());
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  fare(s: Omit<Service, 'id'>) {
    const raw = Number(s.baseFare) + Number(s.perKm) * this.km + Number(s.perMinute) * this.min;
    return Math.ceil(Math.max(Number(s.minimumFare), raw));
  }

  commission(s: Omit<Service, 'id'>) {
    return Math.round(this.fare(s) * Number(s.commissionPercent)) / 100;
  }

  add() {
    this.list.update((l) => [...l, { name: 'New type', description: '', seats: 4, baseFare: 10, perKm: 5, perMinute: 0.5, minimumFare: 20, commissionPercent: 15, isActive: false, sortOrder: l.length + 1 }]);
  }

  async save(s: Omit<Service, 'id'> & { id?: string }) {
    this.busy.set(true);
    try {
      const out = await this.api.saveService({ ...s, baseFare: +s.baseFare, perKm: +s.perKm, perMinute: +s.perMinute, minimumFare: +s.minimumFare, commissionPercent: +s.commissionPercent, seats: +s.seats });
      Object.assign(s, out);
      this.error.set('');
      this.saved.set(`${out.name} saved`);
      setTimeout(() => this.saved.set(''), 2500);
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.busy.set(false);
    }
  }
}
