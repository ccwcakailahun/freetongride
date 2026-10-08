namespace FreeTongRide.Domain.Enums;

public enum UserRole { Passenger = 1, Driver = 2, Admin = 3 }

public enum DriverStatus
{
    PendingDocuments = 0,
    UnderReview = 1,
    Approved = 2,
    Rejected = 3,
    Suspended = 4
}

/// <summary>Lifecycle of a ride, shared by the passenger app, driver app and admin panel.</summary>
public enum RideStatus
{
    /// <summary>Requested; drivers in range can send offers.</summary>
    Searching = 0,
    /// <summary>Passenger accepted an offer; driver is heading to pickup.</summary>
    DriverAssigned = 1,
    /// <summary>Driver is at the pickup point.</summary>
    DriverArrived = 2,
    /// <summary>Pickup code verified; trip running.</summary>
    InProgress = 3,
    /// <summary>Driver ended the trip; waiting for payment.</summary>
    AwaitingPayment = 4,
    Completed = 5,
    Cancelled = 9
}

public enum BidStatus { Pending = 0, Accepted = 1, Declined = 2, Withdrawn = 3, Expired = 4 }

public enum PaymentMethod { Cash = 1, Wallet = 2, OrangeMoney = 3, Card = 4 }

public enum PaymentStatus { Unpaid = 0, Paid = 1, Failed = 2 }

public enum WalletTxType { TopUp = 1, RidePayment = 2, RideEarning = 3, Commission = 4, Tip = 5, Withdrawal = 6, Refund = 7, Adjustment = 8 }

public enum WithdrawalStatus { Pending = 0, Approved = 1, Rejected = 2 }

public enum SosStatus { Open = 0, Acknowledged = 1, Resolved = 2 }

public enum OtpPurpose { VerifyPhone = 1, ResetPassword = 2 }

public enum DocumentType { DrivingLicence = 1, NationalId = 2, ProfilePhoto = 3, VehiclePhoto = 4, VehicleRegistration = 5, Insurance = 6 }
