import { Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminApi, errorText } from '../core/api';
import { LePipe } from '../core/format';
import { Paged, TxRow } from '../core/models';
import { Pager } from './shared';

/** Every wallet movement: top-ups, ride payments, driver earnings, commission, tips, withdrawals. */
@Component({
  selector: 'ftr-transactions',
  imports: [FormsModule, DatePipe, LePipe, Pager],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>Transactions</h1><p>The wallet ledger. Each line shows the balance right after it.</p></div>
        <select class="input" [(ngModel)]="type" (change)="page = 1; load()">
          <option value="">All types</option>
          @for (t of types; track t) { <option [value]="t">{{ t }}</option> }
        </select>
        <div class="search"><input class="input" placeholder="Name, phone or description" [(ngModel)]="search" (keyup.enter)="page = 1; load()" /></div>
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      <div class="card">
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>When</th><th>Who</th><th>Type</th><th>Description</th><th class="right">Amount</th><th class="right">Balance after</th></tr></thead>
            <tbody>
              @for (t of data()?.items ?? []; track t.id) {
                <tr>
                  <td class="small num">{{ t.createdAt | date: 'd MMM, HH:mm' }}</td>
                  <td><b>{{ t.userName }}</b><div class="small">{{ t.role }}</div></td>
                  <td><span class="pill grey">{{ t.type }}</span></td>
                  <td>{{ t.description }}@if (t.reference) { <div class="mono small">{{ t.reference }}</div> }</td>
                  <td class="right num" [style.color]="t.amount >= 0 ? '#0e8d4e' : 'var(--ink)'"><b>{{ t.amount | le: true }}</b></td>
                  <td class="right num">{{ t.balanceAfter | le }}</td>
                </tr>
              } @empty { <tr><td colspan="6" class="empty">No transactions.</td></tr> }
            </tbody>
          </table>
        </div>
        @if (data(); as d) { <ftr-pager [page]="page" [pageSize]="30" [total]="d.total" (go)="page = $event; load()" /> }
      </div>
    </div>
  `,
})
export class TransactionsPage implements OnInit {
  private readonly api = inject(AdminApi);
  readonly data = signal<Paged<TxRow> | null>(null);
  readonly error = signal('');
  readonly types = ['TopUp', 'RidePayment', 'RideEarning', 'Commission', 'Tip', 'Withdrawal', 'Refund', 'Adjustment'];
  type = '';
  search = '';
  page = 1;

  ngOnInit() { this.load(); }

  async load() {
    try {
      this.data.set(await this.api.transactions({ type: this.type, search: this.search, page: this.page, pageSize: 30 }));
      this.error.set('');
    } catch (e) {
      this.error.set(errorText(e));
    }
  }
}
