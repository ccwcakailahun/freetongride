import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService, errorText } from '../core/api';
import { InitialsPipe, PhonePipe } from '../core/format';

/** The signed-in admin's profile and password. */
@Component({
  selector: 'ftr-account',
  imports: [FormsModule, InitialsPipe, PhonePipe],
  template: `
    <div class="page">
      <div class="page-head">
        <div class="grow"><h1>My account</h1><p>Your admin profile and password.</p></div>
      </div>

      <div class="layout">
        <section class="card pad profile">
          <div class="who-big">
            <div class="avatar lg">{{ (auth.user()?.fullName ?? 'A') | initials }}</div>
            <div>
              <h2>{{ auth.user()?.fullName }}</h2>
              <span class="pill purple">Administrator</span>
            </div>
          </div>
          <form (ngSubmit)="saveProfile()" class="stack">
            <label class="field" for="acc-name">Full name
              <input id="acc-name" class="input" name="name" [(ngModel)]="name" autocomplete="name" required />
            </label>
            <label class="field" for="acc-email">Email (used to sign in)
              <input id="acc-email" class="input" name="email" type="email" [(ngModel)]="email" autocomplete="email" />
            </label>
            <label class="field">Phone
              <input class="input" [value]="auth.user()?.phone | phone" disabled />
            </label>
            @if (profileMsg()) { <div [class]="profileOk() ? 'ok-box' : 'error-box'">{{ profileMsg() }}</div> }
            <div><button class="btn primary" [disabled]="savingProfile()">{{ savingProfile() ? 'Saving…' : 'Save profile' }}</button></div>
          </form>
        </section>

        <section class="card pad">
          <h2>Change password</h2>
          <p class="muted">Choose a strong password you don't use anywhere else. You stay signed in on this device.</p>
          <form (ngSubmit)="changePassword()" class="stack">
            <label class="field" for="acc-current">Current password
              <input id="acc-current" class="input" name="current" [type]="show() ? 'text' : 'password'" [(ngModel)]="current" autocomplete="current-password" required />
            </label>
            <label class="field" for="acc-new">New password
              <input id="acc-new" class="input" name="next" [type]="show() ? 'text' : 'password'" [ngModel]="next()" (ngModelChange)="next.set($event)" autocomplete="new-password" required />
            </label>
            <label class="field" for="acc-confirm">Confirm new password
              <input id="acc-confirm" class="input" name="confirm" [type]="show() ? 'text' : 'password'" [ngModel]="confirm()" (ngModelChange)="confirm.set($event)" autocomplete="new-password" required />
            </label>
            <label class="show"><input type="checkbox" [checked]="show()" (change)="show.set(!show())" /> Show passwords</label>

            <ul class="rules">
              <li [class.met]="rules().length">At least 8 characters</li>
              <li [class.met]="rules().digit">One number</li>
              <li [class.met]="rules().upper">One uppercase letter</li>
              <li [class.met]="rules().match">Both new passwords match</li>
            </ul>

            @if (pwMsg()) { <div [class]="pwOk() ? 'ok-box' : 'error-box'" role="status">{{ pwMsg() }}</div> }
            <div><button class="btn primary" [disabled]="!valid() || !current || changing()">{{ changing() ? 'Updating…' : 'Update password' }}</button></div>
          </form>
        </section>
      </div>
    </div>
  `,
  styles: `
    .layout { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; align-items: start; }
    .stack { display: grid; gap: 14px; margin-top: 16px; }
    .stack .input { width: 100%; height: 46px; }
    .who-big { display: flex; align-items: center; gap: 16px; }
    .who-big h2 { margin-bottom: 6px; }
    .show { display: flex; gap: 8px; align-items: center; font-weight: 600; color: var(--body); }
    .rules { list-style: none; margin: 0; padding: 12px 14px; background: #f4f7fc; border-radius: 12px; display: grid; gap: 8px; }
    .rules li { display: flex; gap: 10px; align-items: center; color: var(--muted); font-weight: 600; }
    .rules li::before { content: '✓'; width: 22px; height: 22px; border-radius: 50%; display: grid; place-items: center; font-size: 12px; background: #e6eaf2; color: var(--faint); }
    .rules li.met { color: var(--ink); }
    .rules li.met::before { background: var(--green-soft); color: var(--green); }
    .ok-box { background: var(--green-soft); color: #0e8d4e; border-radius: 12px; padding: 10px 14px; font-weight: 600; }
  `,
})
export class AccountPage {
  protected readonly auth = inject(AuthService);
  name = this.auth.user()?.fullName ?? '';
  email = this.auth.user()?.email ?? '';
  current = '';
  readonly next = signal('');
  readonly confirm = signal('');
  readonly show = signal(false);
  readonly savingProfile = signal(false);
  readonly profileMsg = signal('');
  readonly profileOk = signal(false);
  readonly changing = signal(false);
  readonly pwMsg = signal('');
  readonly pwOk = signal(false);

  readonly rules = computed(() => {
    const p = this.next();
    return { length: p.length >= 8, digit: /\d/.test(p), upper: /[A-Z]/.test(p), match: p.length > 0 && p === this.confirm() };
  });
  readonly valid = computed(() => Object.values(this.rules()).every(Boolean));

  async saveProfile() {
    this.savingProfile.set(true);
    this.profileMsg.set('');
    try {
      await this.auth.updateProfile(this.name.trim(), this.email.trim());
      this.profileOk.set(true);
      this.profileMsg.set('Profile saved.');
    } catch (e) {
      this.profileOk.set(false);
      this.profileMsg.set(errorText(e));
    } finally {
      this.savingProfile.set(false);
    }
  }

  async changePassword() {
    if (!this.valid()) return;
    this.changing.set(true);
    this.pwMsg.set('');
    try {
      await this.auth.changePassword(this.current, this.next());
      this.pwOk.set(true);
      this.pwMsg.set('Password updated. Use the new password next time you sign in.');
      this.current = '';
      this.next.set('');
      this.confirm.set('');
    } catch (e) {
      this.pwOk.set(false);
      this.pwMsg.set(errorText(e));
    } finally {
      this.changing.set(false);
    }
  }
}
