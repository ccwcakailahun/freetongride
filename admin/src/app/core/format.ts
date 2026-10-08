import { Pipe, PipeTransform } from '@angular/core';

const money = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 });

/** "Le 1,250" — Leones (SLE). */
export function le(v: number | null | undefined, signed = false): string {
  const n = v ?? 0;
  const text = `Le ${money.format(Math.abs(n))}`;
  if (n < 0) return `- ${text}`;
  return signed && n > 0 ? `+ ${text}` : text;
}

export function phone(e164?: string | null): string {
  if (!e164) return '';
  const d = e164.replace(/\D/g, '');
  return d.length === 11 && d.startsWith('232') ? `+232 ${d.slice(3, 5)} ${d.slice(5, 8)} ${d.slice(8)}` : e164;
}

export function ago(iso?: string | null): string {
  if (!iso) return '—';
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 45) return 'just now';
  if (s < 3600) return `${Math.round(s / 60)} min ago`;
  if (s < 86400) return `${Math.round(s / 3600)} h ago`;
  return new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

export function initials(name: string): string {
  const p = name.trim().split(/\s+/);
  return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase();
}

@Pipe({ name: 'le' })
export class LePipe implements PipeTransform {
  transform(v: number | null | undefined, signed = false) { return le(v, signed); }
}

/** 1284 -> "1,284" */
@Pipe({ name: 'count' })
export class CountPipe implements PipeTransform {
  transform(v: number | null | undefined) { return new Intl.NumberFormat('en-US').format(v ?? 0); }
}

@Pipe({ name: 'phone' })
export class PhonePipe implements PipeTransform {
  transform(v?: string | null) { return phone(v); }
}

@Pipe({ name: 'ago' })
export class AgoPipe implements PipeTransform {
  transform(v?: string | null) { return ago(v); }
}

@Pipe({ name: 'initials' })
export class InitialsPipe implements PipeTransform {
  transform(v: string) { return initials(v); }
}
