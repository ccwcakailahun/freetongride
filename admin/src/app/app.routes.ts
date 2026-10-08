import { Routes } from '@angular/router';
import { authGuard } from './core/api';
import { Shell } from './layout/shell';

export const routes: Routes = [
  { path: 'login', loadComponent: () => import('./pages/login').then((m) => m.LoginPage), title: 'Sign in · FreeTongRide Admin' },
  {
    path: '',
    component: Shell,
    canActivate: [authGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'dashboard', loadComponent: () => import('./pages/dashboard').then((m) => m.DashboardPage), title: 'Dashboard · FreeTongRide Admin' },
      { path: 'live', loadComponent: () => import('./pages/live-map').then((m) => m.LiveMapPage), title: 'Live map · FreeTongRide Admin' },
      { path: 'rides', loadComponent: () => import('./pages/rides').then((m) => m.RidesPage), title: 'Rides · FreeTongRide Admin' },
      { path: 'drivers', loadComponent: () => import('./pages/drivers').then((m) => m.DriversPage), title: 'Drivers · FreeTongRide Admin' },
      { path: 'passengers', loadComponent: () => import('./pages/passengers').then((m) => m.PassengersPage), title: 'Passengers · FreeTongRide Admin' },
      { path: 'safety', loadComponent: () => import('./pages/safety').then((m) => m.SafetyPage), title: 'Safety · FreeTongRide Admin' },
      { path: 'payouts', loadComponent: () => import('./pages/payouts').then((m) => m.PayoutsPage), title: 'Payouts · FreeTongRide Admin' },
      { path: 'transactions', loadComponent: () => import('./pages/transactions').then((m) => m.TransactionsPage), title: 'Transactions · FreeTongRide Admin' },
      { path: 'account', loadComponent: () => import('./pages/account').then((m) => m.AccountPage), title: 'My account · FreeTongRide Admin' },
      { path: 'fares', loadComponent: () => import('./pages/fares').then((m) => m.FaresPage), title: 'Ride types & fares · FreeTongRide Admin' },
    ],
  },
  { path: '**', redirectTo: '' },
];
