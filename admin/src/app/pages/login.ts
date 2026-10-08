import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService, errorText } from '../core/api';

@Component({
  selector: 'ftr-login',
  imports: [FormsModule],
  template: `
    <div class="wrap">
      <section class="art">
        <img class="logo" src="logo-full.png" alt="FreeTongRide — Moving Freetown Together" />
        <div class="pitch">
          <h1>Operations console</h1>
          <p>Watch every ride across Freetown live, respond to SOS alerts, approve drivers and keep payouts moving.</p>
        </div>
      </section>
      <section class="form-side">
        <form (ngSubmit)="submit()" class="card">
          <h2>Sign in</h2>
          <p class="muted">Admin accounts only.</p>
          <label class="field">Phone number or email
            <input class="input" name="phone" [(ngModel)]="phone" autocomplete="username" placeholder="+232 76 000 000" required />
          </label>
          <label class="field">Password
            <input class="input" name="password" type="password" [(ngModel)]="password" autocomplete="current-password" required />
          </label>
          @if (error()) { <div class="error-box">{{ error() }}</div> }
          <button class="btn primary big" [disabled]="busy()">{{ busy() ? 'Signing in…' : 'Sign in' }}</button>
        </form>
      </section>
    </div>
  `,
  styles: `
    .wrap { min-height: 100vh; display: grid; grid-template-columns: 1.1fr 1fr; }
    .art { background: radial-gradient(circle at 20% 20%, #eaf2ff, #f8faff 60%); display: grid; align-content: center; justify-items: center; gap: 30px; padding: 40px; }
    .logo { width: min(420px, 80%); }
    .pitch { max-width: 420px; text-align: center; }
    .pitch p { color: var(--muted); font-size: 15px; line-height: 1.6; }
    .form-side { display: grid; place-items: center; padding: 24px 16px; }
    form { width: min(400px, 100%); padding: 28px; display: grid; gap: 16px; }
    form p { margin: -8px 0 4px; }
    .big { height: 48px; font-size: 15px; }
    @media (max-width: 860px) { .wrap { grid-template-columns: 1fr; } .art { padding: 28px 16px 0; } .pitch { display: none; } }
  `,
})
export class LoginPage {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  phone = '';
  password = '';
  readonly busy = signal(false);
  readonly error = signal('');

  async submit() {
    this.busy.set(true);
    this.error.set('');
    try {
      await this.auth.login(this.phone, this.password);
      this.router.navigateByUrl('/dashboard');
    } catch (e) {
      this.error.set(errorText(e));
    } finally {
      this.busy.set(false);
    }
  }
}
