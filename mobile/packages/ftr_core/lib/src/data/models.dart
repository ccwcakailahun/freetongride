// JSON models matching the FreeTongRide API (backend/src/FreeTongRide.Application).

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();
DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);

enum UserRole { passenger, driver, admin }

enum RideStatus { searching, driverAssigned, driverArrived, inProgress, awaitingPayment, completed, cancelled }

enum PaymentMethod { cash, wallet, orangeMoney, card }

enum PaymentStatus { unpaid, paid, failed }

enum BidStatus { pending, accepted, declined, withdrawn, expired }

enum DriverStatus { pendingDocuments, underReview, approved, rejected, suspended }

enum DocumentType { drivingLicence, nationalId, profilePhoto, vehiclePhoto, vehicleRegistration, insurance }

enum WalletTxType { topUp, ridePayment, rideEarning, commission, tip, withdrawal, refund, adjustment }

/// API sends enums as PascalCase strings ("DriverAssigned"); Dart uses camelCase.
T parseEnum<T extends Enum>(List<T> values, dynamic raw) {
  final s = (raw as String).toLowerCase();
  return values.firstWhere((v) => v.name.toLowerCase() == s);
}

String enumToApi(Enum e) => e.name[0].toUpperCase() + e.name.substring(1);

extension RideStatusX on RideStatus {
  bool get isActive => this != RideStatus.completed && this != RideStatus.cancelled;
  bool get hasDriver => this == RideStatus.driverAssigned || this == RideStatus.driverArrived || this == RideStatus.inProgress || this == RideStatus.awaitingPayment;
}

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.wallet => 'Wallet',
        PaymentMethod.orangeMoney => 'Orange Money',
        PaymentMethod.card => 'Card',
      };
}

class AppUser {
  AppUser.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        fullName = j['fullName'],
        phone = j['phone'],
        email = j['email'],
        role = parseEnum(UserRole.values, j['role']),
        phoneVerified = j['phoneVerified'] ?? false,
        photoUrl = j['photoUrl'],
        emergencyContact = j['emergencyContact'],
        homeArea = j['homeArea'],
        walletBalance = _d(j['walletBalance']),
        points = j['points'] ?? 0,
        rating = _d(j['rating']),
        ratingCount = j['ratingCount'] ?? 0;

  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final UserRole role;
  final bool phoneVerified;
  final String? photoUrl;
  final String? emergencyContact;
  final String? homeArea;
  final double walletBalance;
  final int points;
  final double rating;
  final int ratingCount;

  bool get profileComplete => emergencyContact != null && homeArea != null;
}

class OtpSent {
  OtpSent.fromJson(Map<String, dynamic> j)
      : phone = j['phone'],
        resendAfterSeconds = j['resendAfterSeconds'] ?? 60,
        devCode = j['devCode'];
  final String phone;
  final int resendAfterSeconds;

  /// Only present when the API runs in Development.
  final String? devCode;
}

class Place {
  const Place(this.address, this.lat, this.lng, {this.subtitle});
  Place.fromJson(Map<String, dynamic> j)
      : address = j['address'],
        lat = _d(j['lat']),
        lng = _d(j['lng']),
        subtitle = null;
  final String address;
  final String? subtitle;
  final double lat;
  final double lng;
  Map<String, dynamic> toJson() => {'address': address, 'lat': lat, 'lng': lng};
}

class SavedPlace {
  SavedPlace.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        label = j['label'],
        address = j['address'],
        lat = _d(j['lat']),
        lng = _d(j['lng']);
  final String id;
  final String label;
  final String address;
  final double lat;
  final double lng;
  Place get place => Place(address, lat, lng);
}

class ServiceQuote {
  ServiceQuote.fromJson(Map<String, dynamic> j)
      : serviceId = j['serviceId'],
        name = j['name'],
        description = j['description'] ?? '',
        seats = j['seats'] ?? 1,
        fare = _d(j['fare']),
        baseFare = _d(j['baseFare']),
        distanceFare = _d(j['distanceFare']),
        timeFare = _d(j['timeFare']),
        discount = _d(j['discount']),
        distanceKm = _d(j['distanceKm']),
        durationMinutes = j['durationMinutes'] ?? 0,
        nearestDriverMinutes = j['nearestDriverMinutes'],
        driversNearby = j['driversNearby'] ?? 0;
  final String serviceId;
  final String name;
  final String description;
  final int seats;
  final double fare;
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double discount;
  final double distanceKm;
  final int durationMinutes;
  final int? nearestDriverMinutes;
  final int driversNearby;
}

class Person {
  Person.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        fullName = j['fullName'],
        phone = j['phone'],
        photoUrl = j['photoUrl'],
        rating = _d(j['rating']),
        ratingCount = j['ratingCount'] ?? 0;
  final String id;
  final String fullName;
  final String phone;
  final String? photoUrl;
  final double rating;
  final int ratingCount;
}

class Driver {
  Driver.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        fullName = j['fullName'],
        phone = j['phone'],
        photoUrl = j['photoUrl'],
        rating = _d(j['rating']),
        ratingCount = j['ratingCount'] ?? 0,
        completedTrips = j['completedTrips'] ?? 0,
        vehicleMake = j['vehicleMake'],
        vehicleModel = j['vehicleModel'],
        vehicleColor = j['vehicleColor'],
        plateNumber = j['plateNumber'],
        vehicle = j['vehicle'] ?? '',
        lat = _dn(j['lat']),
        lng = _dn(j['lng']),
        heading = _dn(j['heading']);
  final String id;
  final String fullName;
  final String phone;
  final String? photoUrl;
  final double rating;
  final int ratingCount;
  final int completedTrips;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? plateNumber;
  final String vehicle;
  final double? lat;
  final double? lng;
  final double? heading;

  /// "Mohamed K."
  String get shortName {
    final p = fullName.trim().split(RegExp(r'\s+'));
    return p.length > 1 ? '${p.first} ${p.last[0]}.' : fullName;
  }
}

class Bid {
  Bid.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        rideId = j['rideId'],
        amount = _d(j['amount']),
        etaMinutes = j['etaMinutes'] ?? 0,
        status = parseEnum(BidStatus.values, j['status']),
        createdAt = _dt(j['createdAt'])!,
        driver = Driver.fromJson(j['driver']);
  final String id;
  final String rideId;
  final double amount;
  final int etaMinutes;
  final BidStatus status;
  final DateTime createdAt;
  final Driver driver;
}

class Ride {
  Ride.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        code = j['code'],
        status = parseEnum(RideStatus.values, j['status']),
        serviceName = j['serviceName'] ?? '',
        serviceId = j['serviceId'],
        pickup = Place.fromJson(j['pickup']),
        dropoff = Place.fromJson(j['dropoff']),
        distanceKm = _d(j['distanceKm']),
        durationMinutes = j['durationMinutes'] ?? 0,
        estimatedFare = _d(j['estimatedFare']),
        offeredFare = _d(j['offeredFare']),
        agreedFare = _dn(j['agreedFare']),
        discount = _dn(j['discount']),
        tip = _dn(j['tip']),
        fareDue = _d(j['fareDue']),
        commission = _dn(j['commission']),
        paymentMethod = parseEnum(PaymentMethod.values, j['paymentMethod']),
        paymentStatus = parseEnum(PaymentStatus.values, j['paymentStatus']),
        pickupCode = j['pickupCode'],
        passenger = Person.fromJson(j['passenger']),
        driver = j['driver'] == null ? null : Driver.fromJson(j['driver']),
        note = j['note'],
        createdAt = _dt(j['createdAt'])!,
        assignedAt = _dt(j['assignedAt']),
        arrivedAt = _dt(j['arrivedAt']),
        startedAt = _dt(j['startedAt']),
        endedAt = _dt(j['endedAt']),
        completedAt = _dt(j['completedAt']),
        cancelledAt = _dt(j['cancelledAt']),
        cancelReason = j['cancelReason'],
        myRating = j['myRating'];

  final String id;
  final String code;
  final RideStatus status;
  final String serviceName;
  final String serviceId;
  final Place pickup;
  final Place dropoff;
  final double distanceKm;
  final int durationMinutes;
  final double estimatedFare;
  final double offeredFare;
  final double? agreedFare;
  final double? discount;
  final double? tip;
  final double fareDue;
  final double? commission;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? pickupCode;
  final Person passenger;
  final Driver? driver;
  final String? note;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final int? myRating;

  double get fare => agreedFare ?? offeredFare;
}

class RideRequest {
  RideRequest.fromJson(Map<String, dynamic> j)
      : rideId = j['rideId'],
        code = j['code'],
        serviceName = j['serviceName'],
        pickup = Place.fromJson(j['pickup']),
        dropoff = Place.fromJson(j['dropoff']),
        distanceKm = _d(j['distanceKm']),
        durationMinutes = j['durationMinutes'] ?? 0,
        pickupDistanceKm = _d(j['pickupDistanceKm']),
        offeredFare = _d(j['offeredFare']),
        estimatedFare = _d(j['estimatedFare']),
        paymentMethod = parseEnum(PaymentMethod.values, j['paymentMethod']),
        passengerName = j['passengerName'],
        passengerPhotoUrl = j['passengerPhotoUrl'],
        passengerRating = _d(j['passengerRating']),
        createdAt = _dt(j['createdAt'])!,
        myBid = _dn(j['myBid']);
  final String rideId;
  final String code;
  final String serviceName;
  final Place pickup;
  final Place dropoff;
  final double distanceKm;
  final int durationMinutes;
  final double pickupDistanceKm;
  final double offeredFare;
  final double estimatedFare;
  final PaymentMethod paymentMethod;
  final String passengerName;
  final String? passengerPhotoUrl;
  final double passengerRating;
  final DateTime createdAt;
  final double? myBid;
}

class WalletTx {
  WalletTx.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        type = parseEnum(WalletTxType.values, j['type']),
        amount = _d(j['amount']),
        balanceAfter = _d(j['balanceAfter']),
        description = j['description'] ?? '',
        rideId = j['rideId'],
        createdAt = _dt(j['createdAt'])!;
  final String id;
  final WalletTxType type;
  final double amount;
  final double balanceAfter;
  final String description;
  final String? rideId;
  final DateTime createdAt;
}

class WalletSummary {
  WalletSummary.fromJson(Map<String, dynamic> j)
      : balance = _d(j['balance']),
        points = j['points'] ?? 0,
        recent = (j['recent'] as List).map((e) => WalletTx.fromJson(e)).toList();
  final double balance;
  final int points;
  final List<WalletTx> recent;
}

class Earnings {
  Earnings.fromJson(Map<String, dynamic> j)
      : balance = _d(j['balance']),
        today = _d(j['today']),
        thisWeek = _d(j['thisWeek']),
        tripsToday = j['tripsToday'] ?? 0,
        tripsThisWeek = j['tripsThisWeek'] ?? 0,
        commissionThisWeek = _d(j['commissionThisWeek']),
        rating = _d(j['rating']),
        recent = (j['recent'] as List).map((e) => WalletTx.fromJson(e)).toList();
  final double balance;
  final double today;
  final double thisWeek;
  final int tripsToday;
  final int tripsThisWeek;
  final double commissionThisWeek;
  final double rating;
  final List<WalletTx> recent;
}

class ServiceInfo {
  ServiceInfo.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        description = j['description'] ?? '',
        seats = j['seats'] ?? 1;
  final String id;
  final String name;
  final String description;
  final int seats;
}

class DriverDocument {
  DriverDocument.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        type = parseEnum(DocumentType.values, j['type']),
        fileUrl = j['fileUrl'],
        approved = j['approved'];
  final String id;
  final DocumentType type;
  final String fileUrl;
  final bool? approved;
}

class DriverProfile {
  DriverProfile.fromJson(Map<String, dynamic> j)
      : status = parseEnum(DriverStatus.values, j['status']),
        rejectReason = j['rejectReason'],
        serviceId = j['serviceId'],
        serviceName = j['serviceName'],
        licenceNumber = j['licenceNumber'],
        vehicleMake = j['vehicleMake'],
        vehicleModel = j['vehicleModel'],
        vehicleColor = j['vehicleColor'],
        vehicleYear = j['vehicleYear'],
        plateNumber = j['plateNumber'],
        isOnline = j['isOnline'] ?? false,
        completedTrips = j['completedTrips'] ?? 0,
        documents = (j['documents'] as List).map((e) => DriverDocument.fromJson(e)).toList(),
        missingDocuments = (j['missingDocuments'] as List).map((e) => parseEnum(DocumentType.values, e)).toList();
  final DriverStatus status;
  final String? rejectReason;
  final String? serviceId;
  final String? serviceName;
  final String? licenceNumber;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final int? vehicleYear;
  final String? plateNumber;
  final bool isOnline;
  final int completedTrips;
  final List<DriverDocument> documents;
  final List<DocumentType> missingDocuments;

  bool get hasVehicle => plateNumber != null && serviceId != null;
}

class Withdrawal {
  Withdrawal.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        amount = _d(j['amount']),
        method = j['method'],
        accountNumber = j['accountNumber'],
        status = j['status'],
        createdAt = _dt(j['createdAt'])!;
  final String id;
  final double amount;
  final String method;
  final String accountNumber;
  final String status;
  final DateTime createdAt;
}

class ChatMessage {
  ChatMessage.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        rideId = j['rideId'],
        senderId = j['senderId'],
        text = j['text'],
        createdAt = _dt(j['createdAt'])!;
  final String id;
  final String rideId;
  final String senderId;
  final String text;
  final DateTime createdAt;
}

class Paged<T> {
  Paged(this.items, this.total);
  final List<T> items;
  final int total;
}
