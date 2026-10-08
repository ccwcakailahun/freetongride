import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService, errorText } from '../core/api';

@Component({
  selector: 'ftr-login',
  imports: [FormsModule],
  template: `
    <div class="wrap">
      <!-- Brand panel -->
      <section class="brand-panel" aria-hidden="true">
        <div class="glow g1"></div><div class="glow g2"></div>
        <div class="road"></div>
        <div class="brand-top">
          <img src="logo-mark.png" alt="" />
          <div><b>FreeTong<em>Ride</em></b><small>Moving Freetown Together</small></div>
        </div>
        <div class="pitch">
          <span class="eyebrow">Operations console</span>
          <h1>Every ride across Freetown, <span>in one view.</span></h1>
          <p>Watch trips live, respond to SOS alerts the moment they happen, approve drivers and keep payouts moving.</p>
          <ul class="points">
            <li><i class="dot green"></i><div><b>Live map &amp; rides</b><span>Drivers and trips update in real time.</span></div></li>
            <li><i class="dot red"></i><div><b>Safety first</b><span>SOS alerts with location and emergency contacts.</span></div></li>
            <li><i class="dot blue"></i><div><b>Money under control</b><span>Fares, commission, wallets and driver payouts.</span></div></li>
          </ul>
        </div>
        <p class="foot">© {{ year }} FreeTongRide · Freetown, Sierra Leone</p>
      </section>

      <!-- Form -->
      <section class="form-panel">
        <div class="form-box">
          <div class="mobile-brand"><img src="logo-mark.png" alt="" /><b>FreeTong<em>Ride</em></b></div>
          <h2>Sign in to the admin console</h2>
          <p class="lead">Use the administrator account for your team.</p>

          <form (ngSubmit)="submit()" novalidate>
            <label class="field" for="login-id">
              <span>Email or phone number</span>
              <div class="control">
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 6h16v12H4z M4 7l8 6 8-6" /></svg>
                <input id="login-id" name="id" [(ngModel)]="id" autocomplete="username" placeholder="admin@freetongride.dorwei.com" required autofocus />
              </div>
            </label>

            <label class="field" for="login-pass">
              <span>Password</span>
              <div class="control">
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 11h12v9H6z M8.5 11V8a3.5 3.5 0 0 1 7 0v3" /></svg>
                <input id="login-pass" name="password" [type]="show() ? 'text' : 'password'" [(ngModel)]="password"
                  autocomplete="current-password" placeholder="Your password" required (keyup)="caps.set($any($event).getModifierState?.('CapsLock'))" />
                <button type="button" class="eye" (click)="show.set(!show())" [attr.aria-label]="show() ? 'Hide password' : 'Show password'">
                  {{ show() ? 'Hide' : 'Show' }}
                </button>
              </div>
              @if (caps()) { <small class="hint warn">Caps Lock is on.</small> }
            </label>

            <div class="row">
              <label class="check"><input type="checkbox" name="remember" [(ngModel)]="remember" /> Keep me signed in</label>
            </div>

            @if (error()) {
              <div class="error" role="alert">
                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3 2 21h20L12 3zm0 6v5m0 3h.01" /></svg>
                <span>{{ error() }}</span>
              </div>
            }

            <button class="submit" [disabled]="busy() || !id.trim() || !password">
              @if (busy()) { <span class="spinner"></span> Signing in… } @else { Sign in <span aria-hidden="true">→</span> }
            </button>
          </form>

          <div class="help">
            <p><b>Forgot your password?</b> Ask the server owner to reset it. There is no email reset for admin accounts.</p>
          </div>

          <a class="apps" href="/download/">
            <img src="logo-mark.png" alt="" />
            <span><b>Get the FreeTongRide apps</b><small>Passenger and driver apps for Android</small></span>
            <span aria-hidden="true">→</span>
          </a>
        </div>
      </section>
    </div>
  `,
  styles: `
    :host { display: block; }
    .wrap { min-height: 100vh; display: grid; grid-template-columns: minmax(0, 1.05fr) minmax(0, 1fr); background: #fff; }

    /* Brand panel */
    .brand-panel { position: relative; overflow: hidden; color: #dfe6ff; padding: 44px 56px; display: flex; flex-direction: column; justify-content: space-between;
      background: radial-gradient(1200px 600px at 10% -10%, #1a3fd1 0%, transparent 60%), linear-gradient(160deg, #0b1442 0%, #0d1d63 55%, #0a2a8a 100%); }
    .glow { position: absolute; border-radius: 50%; filter: blur(60px); opacity: 0.55; pointer-events: none; }
    .g1 { width: 420px; height: 420px; background: #1fd36f; right: -140px; top: 22%; opacity: 0.22; }
    .g2 { width: 360px; height: 360px; background: #2f7bff; left: -120px; bottom: -80px; opacity: 0.35; }
    .road { position: absolute; right: -60px; bottom: -40px; width: 520px; height: 520px; border-radius: 50%;
      border: 26px solid rgba(255, 255, 255, 0.04); box-shadow: inset 0 0 0 2px rgba(255, 255, 255, 0.05); }
    .road::after { content: ''; position: absolute; inset: 40px; border-radius: 50%; border: 3px dashed rgba(255, 255, 255, 0.12); }
    .brand-top { display: flex; align-items: center; gap: 14px; position: relative; }
    .brand-top img { width: 48px; height: 52px; object-fit: contain; }
    .brand-top b { display: block; font-size: 24px; font-weight: 800; color: #fff; letter-spacing: -0.03em; }
    .brand-top em, .mobile-brand em { font-style: normal; color: #5fe39b; }
    .brand-top small { color: #9fb0e8; font-size: 11px; letter-spacing: 0.16em; text-transform: uppercase; }
    .pitch { position: relative; max-width: 520px; }
    .eyebrow { display: inline-block; font-size: 12px; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: #5fe39b;
      background: rgba(95, 227, 155, 0.1); border: 1px solid rgba(95, 227, 155, 0.25); padding: 6px 12px; border-radius: 999px; }
    .pitch h1 { color: #fff; font-size: clamp(30px, 3.4vw, 44px); line-height: 1.1; margin: 18px 0 14px; letter-spacing: -0.03em; text-wrap: balance; }
    .pitch h1 span { background: linear-gradient(90deg, #6ea5ff, #5fe39b); -webkit-background-clip: text; background-clip: text; color: transparent; }
    .pitch p { font-size: 16px; line-height: 1.6; color: #b9c5ef; margin: 0 0 28px; }
    .points { list-style: none; margin: 0; padding: 0; display: grid; gap: 16px; }
    .points li { display: flex; gap: 14px; align-items: flex-start; }
    .points b { color: #fff; display: block; font-size: 15px; }
    .points span { color: #9fb0e8; font-size: 13.5px; }
    .dot { width: 12px; height: 12px; border-radius: 50%; margin-top: 4px; flex: none; box-shadow: 0 0 0 5px rgba(255, 255, 255, 0.06); }
    .dot.green { background: #22d36f; } .dot.red { background: #ff6b70; } .dot.blue { background: #5b8cff; }
    .foot { position: relative; color: #7f8fc7; font-size: 12.5px; margin: 0; }

    /* Form panel */
    .form-panel { display: grid; place-items: center; padding: 40px 24px; background: linear-gradient(180deg, #f7f9ff, #fff); }
    .form-box { width: min(420px, 100%); display: grid; gap: 18px; }
    .mobile-brand { display: none; align-items: center; gap: 10px; }
    .mobile-brand img { width: 36px; height: 40px; object-fit: contain; }
    .mobile-brand b { font-size: 20px; font-weight: 800; color: var(--ink); }
    h2 { font-size: 28px; font-weight: 800; letter-spacing: -0.03em; color: var(--ink); }
    .lead { margin: -10px 0 4px; color: var(--muted); font-size: 15px; }
    form { display: grid; gap: 16px; }
    .field { display: grid; gap: 8px; }
    .field > span { font-size: 13px; font-weight: 700; color: var(--ink); }
    .control { display: flex; align-items: center; gap: 10px; height: 54px; padding: 0 14px; background: #fff; border: 1.5px solid var(--border);
      border-radius: 14px; transition: border-color 0.15s, box-shadow 0.15s; }
    .control:focus-within { border-color: var(--blue); box-shadow: 0 0 0 4px rgba(26, 92, 255, 0.12); }
    .control svg { width: 20px; height: 20px; fill: none; stroke: var(--faint); stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; flex: none; }
    .control input { flex: 1; min-width: 0; border: 0; outline: 0; font: inherit; font-size: 15.5px; color: var(--ink); background: transparent; }
    .control input::placeholder { color: var(--faint); }
    .eye { border: 0; background: none; color: var(--blue); font-weight: 700; font-size: 13px; cursor: pointer; padding: 6px; border-radius: 8px; }
    .eye:focus-visible { outline: 2px solid var(--blue); }
    .hint.warn { color: var(--orange); font-weight: 600; }
    .row { display: flex; align-items: center; justify-content: space-between; }
    .check { display: flex; align-items: center; gap: 8px; color: var(--body); font-weight: 600; font-size: 14px; cursor: pointer; }
    .check input { width: 18px; height: 18px; accent-color: var(--blue); }
    .error { display: flex; gap: 10px; align-items: flex-start; background: var(--red-soft); color: #b42318; border: 1px solid rgba(229, 72, 77, 0.25);
      padding: 12px 14px; border-radius: 12px; font-weight: 600; font-size: 14px; }
    .error svg { width: 20px; height: 20px; flex: none; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; }
    .submit { height: 54px; border: 0; border-radius: 14px; font: inherit; font-size: 16px; font-weight: 800; color: #fff; cursor: pointer;
      background: linear-gradient(90deg, #2f7bff, #0b47e6); box-shadow: 0 12px 24px rgba(26, 92, 255, 0.28); display: flex; align-items: center; justify-content: center; gap: 10px;
      transition: transform 0.08s, box-shadow 0.15s, opacity 0.15s; }
    .submit:hover:not([disabled]) { box-shadow: 0 14px 30px rgba(26, 92, 255, 0.36); }
    .submit:active:not([disabled]) { transform: translateY(1px); }
    .submit[disabled] { opacity: 0.55; cursor: not-allowed; box-shadow: none; }
    .submit:focus-visible { outline: 3px solid rgba(26, 92, 255, 0.4); outline-offset: 2px; }
    .spinner { width: 18px; height: 18px; border-radius: 50%; border: 2.5px solid rgba(255, 255, 255, 0.4); border-top-color: #fff; animation: spin 0.8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    .help { border-top: 1px solid var(--border); padding-top: 14px; }
    .help p { margin: 0; font-size: 13.5px; color: var(--muted); line-height: 1.5; }
    .help b { color: var(--ink); }
    .apps { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-radius: 14px; border: 1px solid var(--border); background: #fff; color: var(--ink); }
    .apps:hover { border-color: var(--blue); }
    .apps img { width: 30px; height: 34px; object-fit: contain; }
    .apps span:nth-child(2) { flex: 1; }
    .apps b { display: block; font-size: 14px; }
    .apps small { color: var(--muted); font-weight: 500; }

    @media (max-width: 920px) {
      .wrap { grid-template-columns: 1fr; }
      .brand-panel { display: none; }
      .mobile-brand { display: flex; }
      .form-panel { align-items: start; padding-top: 48px; }
    }
    @media (prefers-reduced-motion: reduce) { .spinner { animation: none; } }
  `,
})
export class LoginPage {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  readonly year = new Date().getFullYear();
  id = '';
  password = '';
  remember = true;
  readonly show = signal(false);
  readonly caps = signal(false);
  readonly busy = signal(false);
  readonly error = signal('');

  async submit() {
    if (!this.id.trim() || !this.password) return;
    this.busy.set(true);
    this.error.set('');
    try {
      await this.auth.login(this.id, this.password, this.remember);
      this.router.navigateByUrl('/dashboard');
    } catch (e) {
      const msg = errorText(e);
      this.error.set(msg.includes('incorrect') ? 'That email/phone and password don’t match an admin account. Check for typos and Caps Lock.' : msg);
    } finally {
      this.busy.set(false);
    }
  }
}
