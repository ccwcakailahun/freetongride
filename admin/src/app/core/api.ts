import { HttpClient, HttpErrorResponse, HttpInterceptorFn, HttpParams } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { firstValueFrom, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import {
  AuthResponse, Dashboard, DriverDetail, DriverRow, DriverStatus, LiveMap, Paged, PassengerRow, Ride, RideDetail, RideStatus,
  Service, Sos, SosStatus, TxRow, UserDto, WithdrawalRow, WithdrawalStatus,
} from './models';

/** API base URL. Override at deploy time with window.FTR_API_URL in index.html. */
export const API_URL: string = (window as unknown as { FTR_API_URL?: string }).FTR_API_URL ?? 'http://localhost:5080';

/**
 * Map tiles. OpenStreetMap's own servers are fine for development and light use; for production set
 * window.FTR_TILE_URL to a provider with a key (MapTiler, Stadia, etc.).
 */
export const TILE_URL: string =
  (window as unknown as { FTR_TILE_URL?: string }).FTR_TILE_URL ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

export function absolute(path?: string | null): string | null {
  if (!path) return null;
  return path.startsWith('http') ? path : `${API_URL}${path}`;
}

/** Message from a ProblemDetails error, written by the API for people to read. */
export function errorText(e: unknown): string {
  if (e instanceof HttpErrorResponse) {
    if (e.status === 0) return 'Cannot reach the FreeTongRide API. Check that it is running.';
    return e.error?.detail ?? e.error?.title ?? `Request failed (${e.status}).`;
  }
  return 'Something went wrong. Please try again.';
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly key = 'ftr_admin_session';
  readonly session = signal<{ token: string; user: UserDto; expiresAt: string } | null>(this.load());
  readonly user = computed(() => this.session()?.user ?? null);
  readonly token = computed(() => this.session()?.token ?? null);

  async login(phone: string, password: string) {
    const r = await firstValueFrom(this.http.post<AuthResponse>(`${API_URL}/api/auth/admin/login`, { phone, password }));
    const s = { token: r.accessToken, user: r.user, expiresAt: r.expiresAt };
    try { localStorage.setItem(this.key, JSON.stringify(s)); } catch { /* storage blocked: session lasts this tab only */ }
    this.session.set(s);
  }

  logout() {
    try { localStorage.removeItem(this.key); } catch { /* ignore */ }
    this.session.set(null);
    this.router.navigateByUrl('/login');
  }

  private load() {
    try {
      const raw = localStorage.getItem(this.key);
      if (!raw) return null;
      const s = JSON.parse(raw);
      return new Date(s.expiresAt) > new Date() ? s : null;
    } catch {
      return null;
    }
  }
}

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  return auth.token() ? true : inject(Router).parseUrl('/login');
};

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.token();
  const authed = token && req.url.startsWith(API_URL) ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req;
  return next(authed).pipe(
    catchError((e: HttpErrorResponse) => {
      if (e.status === 401 && token) auth.logout();
      return throwError(() => e);
    }),
  );
};

function params(obj: Record<string, string | number | boolean | null | undefined>) {
  let p = new HttpParams();
  for (const [k, v] of Object.entries(obj)) if (v !== null && v !== undefined && v !== '') p = p.set(k, String(v));
  return p;
}

@Injectable({ providedIn: 'root' })
export class AdminApi {
  private readonly http = inject(HttpClient);
  private readonly base = `${API_URL}/api/admin`;

  dashboard = () => firstValueFrom(this.http.get<Dashboard>(`${this.base}/dashboard`));
  live = () => firstValueFrom(this.http.get<LiveMap>(`${this.base}/live`));

  rides = (q: { status?: RideStatus | ''; search?: string; from?: string; to?: string; page?: number; pageSize?: number }) =>
    firstValueFrom(this.http.get<Paged<Ride>>(`${this.base}/rides`, { params: params(q) }));
  ride = (id: string) => firstValueFrom(this.http.get<RideDetail>(`${this.base}/rides/${id}`));
  cancelRide = (id: string, reason: string) => firstValueFrom(this.http.post<Ride>(`${this.base}/rides/${id}/cancel`, { reason }));

  drivers = (q: { status?: DriverStatus | ''; online?: boolean | null; search?: string; page?: number; pageSize?: number }) =>
    firstValueFrom(this.http.get<Paged<DriverRow>>(`${this.base}/drivers`, { params: params(q) }));
  driver = (id: string) => firstValueFrom(this.http.get<DriverDetail>(`${this.base}/drivers/${id}`));
  reviewDriver = (id: string, approve: boolean, reason?: string) =>
    firstValueFrom(this.http.post<DriverDetail>(`${this.base}/drivers/${id}/review`, { approve, reason }));
  suspendDriver = (id: string, suspended: boolean) => firstValueFrom(this.http.post<void>(`${this.base}/drivers/${id}/suspend`, { suspended }));

  passengers = (q: { search?: string; page?: number; pageSize?: number }) =>
    firstValueFrom(this.http.get<Paged<PassengerRow>>(`${this.base}/passengers`, { params: params(q) }));
  setActive = (id: string, active: boolean) => firstValueFrom(this.http.post<void>(`${this.base}/users/${id}/active`, { active }));

  sos = (openOnly = false) => firstValueFrom(this.http.get<Sos[]>(`${this.base}/sos`, { params: params({ openOnly }) }));
  updateSos = (id: string, status: SosStatus, note?: string) => firstValueFrom(this.http.post<Sos>(`${this.base}/sos/${id}`, { status, note }));

  withdrawals = (q: { status?: WithdrawalStatus | ''; page?: number; pageSize?: number }) =>
    firstValueFrom(this.http.get<Paged<WithdrawalRow>>(`${this.base}/withdrawals`, { params: params(q) }));
  processWithdrawal = (id: string, approve: boolean, reason?: string) =>
    firstValueFrom(this.http.post<void>(`${this.base}/withdrawals/${id}`, { approve, reason }));

  transactions = (q: { type?: string; search?: string; page?: number; pageSize?: number }) =>
    firstValueFrom(this.http.get<Paged<TxRow>>(`${this.base}/transactions`, { params: params(q) }));

  services = () => firstValueFrom(this.http.get<Service[]>(`${this.base}/services`));
  saveService = (s: Omit<Service, 'id'> & { id?: string }) =>
    s.id ? firstValueFrom(this.http.put<Service>(`${this.base}/services/${s.id}`, s)) : firstValueFrom(this.http.post<Service>(`${this.base}/services`, s));
}
