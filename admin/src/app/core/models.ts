// Shapes returned by the FreeTongRide API (backend/src/FreeTongRide.Application).

export type RideStatus = 'Searching' | 'DriverAssigned' | 'DriverArrived' | 'InProgress' | 'AwaitingPayment' | 'Completed' | 'Cancelled';
export type DriverStatus = 'PendingDocuments' | 'UnderReview' | 'Approved' | 'Rejected' | 'Suspended';
export type PaymentMethod = 'Cash' | 'Wallet' | 'OrangeMoney' | 'Card';
export type SosStatus = 'Open' | 'Acknowledged' | 'Resolved';
export type WithdrawalStatus = 'Pending' | 'Approved' | 'Rejected';
export type UserRole = 'Passenger' | 'Driver' | 'Admin';

export interface Paged<T> { items: T[]; total: number; page: number; pageSize: number; }

export interface UserDto { id: string; fullName: string; phone: string; email?: string; role: UserRole; photoUrl?: string; }
export interface AuthResponse { accessToken: string; expiresAt: string; user: UserDto; }

export interface PlacePoint { address: string; lat: number; lng: number; }
export interface Person { id: string; fullName: string; phone: string; photoUrl?: string; rating: number; ratingCount: number; }
export interface Driver extends Person {
  completedTrips: number; vehicle: string; plateNumber?: string; vehicleMake?: string; vehicleModel?: string; vehicleColor?: string;
  lat?: number; lng?: number;
}

export interface Ride {
  id: string; code: string; status: RideStatus; serviceName: string; serviceId: string;
  pickup: PlacePoint; dropoff: PlacePoint; distanceKm: number; durationMinutes: number;
  estimatedFare: number; offeredFare: number; agreedFare?: number; discount?: number; tip?: number; fareDue: number; commission?: number;
  paymentMethod: PaymentMethod; paymentStatus: 'Unpaid' | 'Paid' | 'Failed';
  passenger: Person; driver?: Driver;
  createdAt: string; assignedAt?: string; arrivedAt?: string; startedAt?: string; endedAt?: string; completedAt?: string; cancelledAt?: string;
  cancelledBy?: UserRole; cancelReason?: string;
}

export interface Bid { id: string; rideId: string; amount: number; etaMinutes: number; status: string; createdAt: string; driver: Driver; }
export interface Message { id: string; rideId: string; senderId: string; text: string; createdAt: string; }

export interface Sos {
  id: string; rideId: string; rideCode: string; status: SosStatus; lat?: number; lng?: number; message?: string;
  raisedByName: string; raisedByPhone: string; raisedByRole: UserRole; emergencyContact?: string; createdAt: string; resolvedAt?: string; resolutionNote?: string;
}

export interface RideDetail { ride: Ride; bids: Bid[]; messages: Message[]; sos: Sos[]; }

export interface DailyPoint { day: string; rides: number; gmv: number; commission: number; }
export interface Dashboard {
  ridesToday: number; completedToday: number; cancelledToday: number; activeRides: number; searchingRides: number;
  gmvToday: number; commissionToday: number; driversOnline: number; driversPendingReview: number;
  passengersTotal: number; driversTotal: number; newPassengersToday: number; openSos: number;
  pendingWithdrawals: number; pendingWithdrawalAmount: number;
  last14Days: DailyPoint[]; serviceSplitToday: { service: string; rides: number }[];
}

export interface DriverRow {
  id: string; fullName: string; phone: string; email?: string; photoUrl?: string; status: DriverStatus; serviceName?: string;
  vehicle: string; plateNumber?: string; isOnline: boolean; rating: number; ratingCount: number; completedTrips: number;
  walletBalance: number; isActive: boolean; createdAt: string; lastSeenAt?: string; phoneVerified: boolean;
}
export interface DriverDocument { id: string; type: string; fileUrl: string; approved?: boolean; note?: string; createdAt: string; }
export interface DriverProfile {
  status: DriverStatus; rejectReason?: string; serviceName?: string; licenceNumber?: string; vehicleMake?: string; vehicleModel?: string;
  vehicleColor?: string; vehicleYear?: number; plateNumber?: string; documents: DriverDocument[]; missingDocuments: string[];
}
export interface DriverDetail { driver: DriverRow; profile: DriverProfile; recentRides: Ride[]; }

export interface PassengerRow {
  id: string; fullName: string; phone: string; email?: string; photoUrl?: string; phoneVerified: boolean; isActive: boolean;
  rating: number; walletBalance: number; rides: number; createdAt: string; lastLoginAt?: string;
}

export interface WithdrawalRow {
  id: string; driverId: string; driverName: string; driverPhone: string; amount: number; method: string; accountNumber: string;
  status: WithdrawalStatus; adminNote?: string; createdAt: string; processedAt?: string;
}

export interface TxRow { id: string; userName: string; role: UserRole; type: string; amount: number; balanceAfter: number; description: string; reference?: string; createdAt: string; }

export interface Service {
  id: string; name: string; description: string; seats: number; baseFare: number; perKm: number; perMinute: number;
  minimumFare: number; commissionPercent: number; isActive: boolean; sortOrder: number;
}

export interface LiveDriver { id: string; fullName: string; serviceName?: string; plateNumber?: string; lat: number; lng: number; heading?: number; onTrip: boolean; rideId?: string; lastSeenAt?: string; }
export interface LiveMap { drivers: LiveDriver[]; activeRides: Ride[]; }

export const RIDE_STATUS_LABEL: Record<RideStatus, string> = {
  Searching: 'Finding driver',
  DriverAssigned: 'Driver on the way',
  DriverArrived: 'Driver at pickup',
  InProgress: 'On trip',
  AwaitingPayment: 'Awaiting payment',
  Completed: 'Completed',
  Cancelled: 'Cancelled',
};

export const DRIVER_STATUS_LABEL: Record<DriverStatus, string> = {
  PendingDocuments: 'Incomplete',
  UnderReview: 'Needs review',
  Approved: 'Approved',
  Rejected: 'Rejected',
  Suspended: 'Suspended',
};
