import { Component, input, output } from '@angular/core';
import { absolute } from '../core/api';
import { InitialsPipe } from '../core/format';
import { DriverStatus, RIDE_STATUS_LABEL, DRIVER_STATUS_LABEL, RideStatus } from '../core/models';

export function rideTone(s: RideStatus): string {
  return { Searching: 'orange', DriverAssigned: 'blue', DriverArrived: 'purple', InProgress: 'blue', AwaitingPayment: 'orange', Completed: 'green', Cancelled: 'red' }[s];
}

@Component({
  selector: 'ftr-ride-status',
  template: `<span class="pill" [class]="'pill ' + tone()">{{ label() }}</span>`,
})
export class RideStatusPill {
  readonly status = input.required<RideStatus>();
  tone() { return rideTone(this.status()); }
  label() { return RIDE_STATUS_LABEL[this.status()]; }
}

@Component({
  selector: 'ftr-driver-status',
  template: `<span [class]="'pill ' + tone()">{{ label() }}</span>`,
})
export class DriverStatusPill {
  readonly status = input.required<DriverStatus>();
  tone() { return { PendingDocuments: 'grey', UnderReview: 'orange', Approved: 'green', Rejected: 'red', Suspended: 'red' }[this.status()]; }
  label() { return DRIVER_STATUS_LABEL[this.status()]; }
}

@Component({
  selector: 'ftr-avatar',
  imports: [InitialsPipe],
  template: `<div class="avatar" [class.lg]="large()">
    @if (src()) { <img [src]="src()" alt="" (error)="failed = true" [hidden]="failed" /> }
    @if (!src() || failed) { {{ name() | initials }} }
  </div>`,
})
export class Avatar {
  readonly name = input.required<string>();
  readonly photo = input<string | null | undefined>();
  readonly large = input(false);
  failed = false;
  src() { return absolute(this.photo()); }
}

@Component({
  selector: 'ftr-pager',
  template: `<div class="pager">
    <span class="num">{{ from() }}–{{ to() }} of {{ total() }}</span>
    <button class="btn sm" [disabled]="page() <= 1" (click)="go.emit(page() - 1)">Previous</button>
    <button class="btn sm" [disabled]="to() >= total()" (click)="go.emit(page() + 1)">Next</button>
  </div>`,
})
export class Pager {
  readonly page = input.required<number>();
  readonly pageSize = input.required<number>();
  readonly total = input.required<number>();
  readonly go = output<number>();
  from() { return this.total() === 0 ? 0 : (this.page() - 1) * this.pageSize() + 1; }
  to() { return Math.min(this.total(), this.page() * this.pageSize()); }
}
