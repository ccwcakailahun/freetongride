import { Component, computed, input } from '@angular/core';

/** Small stroke icon set (24px grid) so the panel needs no icon font. */
const PATHS: Record<string, string> = {
  dashboard: 'M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z',
  map: 'M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2zm0 0v14m6-12v14',
  car: 'M5 17h14M6 17v2m12-2v2M4 13l2-6h12l2 6v4H4v-4zm3 2h.01M17 15h.01',
  driver: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm-8 9a8 8 0 0 1 16 0',
  users: 'M16 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM8 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm0 2c-3 0-6 1.5-6 4v2h12v-2c0-2.5-3-4-6-4zm8 0c-.5 0-1 0-1.5.1 1.5.9 2.5 2.2 2.5 3.9v2h5v-2c0-2.5-3-4-6-4z',
  shield: 'M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6l-8-3zm0 6v4m0 3h.01',
  wallet: 'M3 7h18v12H3V7zm0 0 3-3h12v3m-2 6h.01',
  receipt: 'M6 3h12v18l-3-2-3 2-3-2-3 2V3zm3 5h6m-6 4h6',
  sliders: 'M4 6h10m4 0h2M4 12h4m4 0h8M4 18h12m4 0h0M14 4v4M8 10v4M16 16v4',
  logout: 'M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10',
  bolt: 'M13 2 4 14h7l-1 8 9-12h-7l1-8z',
  alert: 'M12 3 2 21h20L12 3zm0 6v5m0 3h.01',
  refresh: 'M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7',
  check: 'M5 12l5 5L20 7',
  x: 'M6 6l12 12M18 6 6 18',
  phone: 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z',
  clock: 'M12 7v5l3 3M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z',
};

@Component({
  selector: 'ftr-icon',
  template: `<svg [attr.width]="size()" [attr.height]="size()" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path [attr.d]="d()" /></svg>`,
  styles: ':host{display:inline-flex}',
})
export class Icon {
  readonly name = input.required<string>();
  readonly size = input(20);
  readonly d = computed(() => PATHS[this.name()] ?? '');
}
