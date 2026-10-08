import { Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminApi, errorText } from '../core/api';
import { LePipe, PhonePipe } from '../core/format';
import { Paged, WithdrawalRow, WithdrawalStatus } from '../core/models';
import { Pager } from './shared';

/** Driver withdrawal requests. Money is held from the driver's wallet at request time and returned on rejection. */
@Component({
  selector: 'ftr-payouts',
  imports: [FormsModule, DatePipe, LePipe, PhonePipe, Pager],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>Driver payouts</h1><p>Send the money by Orange Money first, then mark the request approved. Rejecting returns the money to the driver's wallet.</p></div>
        <div class="tabs">
          @for (t of tabs; track t.value) { <button [class.on]="status === t.value" (click)="status = t.value; page = 1; load()">{{ t.label }}</button> }
        </div>
      </div>
      @if (error()) { <div class="error-box">{{ error() }}</div> }
      <div class="card">
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Driver</th><th class="right">Amount</th><th>Pay to</th><th>Requested</th><th>Status</th><th>Note</th><th></th></tr></thead>
            <tbody>
              @for (w of data()?.items ?? []; track w.id) {
                <tr>
                  <td><b>{{ w.driverName }}</b><div class="small">{{ w.driverPhone | phone }}</div></td>
                  <td class="right num"><b>{{ w.amount | le }}</b></td>
                  <td>{{ w.method }}<div class="mono">{{ w.accountNumber }}</div></td>
                  <td class="small">{{ w.createdAt | date: 'd MMM, HH:mm' }}</td>
                  <td><span class="pill" [class.orange]="w.status === 'Pending'" [class.green]="w.status === 'Approved'" [class.red]="w.status === 'Rejected'">{{ w.status }}</span></td>
                  <td>
                    @if (w.status === 'Pending') { <input class="input" style="width:200px" [(ngModel)]="notes[w.id]" placeholder="Reference or reason" /> }
                    @else { <span class="small">{{ w.adminNote ?? '' }}</span> }
                  </td>
                  <td class="right">
                    @if (w.status === 'Pending') {
                      <button class="btn sm ghost-danger" [disabled]="!notes[w.id]?.trim()" (click)="process(w, false)">Reject</button>
                      <button class="btn sm green" (click)="process(w, true)">Mark paid</button>
                    }
                  </td>
                </tr>
              } @empty { <tr><td colspan="7" class="empty">No {{ status ? status.toLowerCase() : '' }} payout requests.</td></tr> }
            </tbody>
          </table>
        </div>
        @if (data(); as d) { <ftr-pager [page]="page" [pageSize]="20" [total]="d.total" (go)="page = $event; load()" /> }
      </div>
    </div>
  `,
  styles: `td .btn + .btn { margin-left: 6px; }`,
})
export class PayoutsPage implements OnInit {
  private readonly api = inject(AdminApi);
  readonly data = signal<Paged<WithdrawalRow> | null>(null);
  readonly error = signal('');
  status: WithdrawalStatus | '' = 'Pending';
  page = 1;
  notes: Record<string, string> = {};
  readonly tabs: { label: string; value: WithdrawalStatus | '' }[] = [
    { label: 'Pending', value: 'Pending' }, { label: 'Paid', value: 'Approved' }, { label: 'Rejected', value: 'Rejected' }, { label: 'All', value: '' },
  ];

  ngOnInit() { this.load(); }

  async load() {
    try {
      this.data.set(await this.api.withdrawals({ status: this.status, page: this.page, pageSize: 20 }));
      this.error.set('');
    } catch (e) {
      this.error.set(errorText(e));
    }
  }

  async process(w: WithdrawalRow, approve: boolean) {
    try {
      await this.api.processWithdrawal(w.id, approve, this.notes[w.id]?.trim());
      this.load();
    } catch (e) {
      this.error.set(errorText(e));
    }
  }
}
