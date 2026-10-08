import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Where the API lives. Override with --dart-define=API_URL=https://api.example.com
String defaultApiUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  // The Android emulator reaches the host machine on 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5080';
  return 'http://localhost:5080';
}

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;

  /// 428: the account exists but the phone is not verified yet.
  bool get needsVerification => status == 428;
  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Thin JSON client. Error responses are ProblemDetails; their "detail" is written for users.
class ApiClient {
  ApiClient({String? baseUrl, FlutterSecureStorage? storage})
      : baseUrl = baseUrl ?? defaultApiUrl(),
        _storage = storage ?? const FlutterSecureStorage();

  final String baseUrl;
  final FlutterSecureStorage _storage;
  final _http = http.Client();
  String? _token;
  static const _tokenKey = 'ftr_access_token';

  /// Called when the API rejects the token, so the app can return to sign-in.
  VoidCallback? onUnauthorized;

  String? get token => _token;

  Future<String?> loadToken() async => _token = await _storage.read(key: _tokenKey);

  Future<void> saveToken(String? token) async {
    _token = token;
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  /// Turns "/uploads/x.jpg" into a full URL.
  String? absolute(String? path) => path == null || path.startsWith('http') ? path : '$baseUrl$path';

  Future<dynamic> get(String path, {Map<String, String?>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> upload(String path, String field, List<int> bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api$path'))
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    final res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 60)));
    return _handle(res);
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String?>? query}) async {
    final q = query == null ? null : {for (final e in query.entries) if (e.value != null) e.key: e.value!};
    final uri = Uri.parse('$baseUrl/api$path').replace(queryParameters: q == null || q.isEmpty ? null : q);
    final req = http.Request(method, uri)..headers['Accept'] = 'application/json';
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      final res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 25)));
      return _handle(res);
    } on TimeoutException {
      throw ApiException('The connection is slow. Check your data and try again.');
    } on http.ClientException {
      throw ApiException('Cannot reach FreeTongRide. Check your internet connection.');
    }
  }

  dynamic _handle(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && _token != null) onUnauthorized?.call();
    final message = data is Map
        ? (data['detail'] ?? _firstValidationError(data) ?? data['title'] ?? 'Something went wrong.')
        : res.statusCode == 429
            ? 'Too many attempts. Wait a minute and try again.'
            : 'Something went wrong. Please try again.';
    throw ApiException(message.toString(), status: res.statusCode);
  }

  String? _firstValidationError(Map data) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return null;
  }
}

class AuthResult {
  AuthResult(this.token, this.user);
  final String token;
  final AppUser user;
}

/// Typed endpoints used by both apps.
class FtrApi {
  FtrApi(this.client);
  final ApiClient client;

  // ---- Auth ----
  Future<OtpSent> register({required String fullName, required String phone, String? email, required String password, UserRole role = UserRole.passenger}) async =>
      OtpSent.fromJson(await client.post('/auth/register', {'fullName': fullName, 'phone': phone, 'email': email, 'password': password, 'role': enumToApi(role)}));

  Future<OtpSent> sendOtp(String phone, {bool reset = false}) async =>
      OtpSent.fromJson(await client.post('/auth/otp', {'phone': phone, 'purpose': reset ? 'ResetPassword' : 'VerifyPhone'}));

  Future<AuthResult> verifyPhone(String phone, String code) async => _auth(await client.post('/auth/verify-phone', {'phone': phone, 'code': code}));

  Future<AuthResult> login(String phone, String password, {UserRole role = UserRole.passenger}) async {
    final path = switch (role) { UserRole.driver => '/auth/driver/login', UserRole.admin => '/auth/admin/login', _ => '/auth/login' };
    return _auth(await client.post(path, {'phone': phone, 'password': password}));
  }

  Future<void> resetPassword(String phone, String code, String newPassword) =>
      client.post('/auth/reset-password', {'phone': phone, 'code': code, 'newPassword': newPassword});

  AuthResult _auth(dynamic j) => AuthResult(j['accessToken'], AppUser.fromJson(j['user']));

  // ---- Me ----
  Future<AppUser> me() async => AppUser.fromJson(await client.get('/me'));
  Future<AppUser> updateMe({String? fullName, String? email, String? emergencyContact, String? homeArea}) async =>
      AppUser.fromJson(await client.put('/me', {'fullName': fullName, 'email': email, 'emergencyContact': emergencyContact, 'homeArea': homeArea}));
  Future<AppUser> uploadPhoto(List<int> bytes, String name) async => AppUser.fromJson(await client.upload('/me/photo', 'file', bytes, name));
  Future<void> setDeviceToken(String token) => client.post('/me/device-token', {'token': token});
  Future<List<SavedPlace>> places() async => (await client.get('/me/places') as List).map((e) => SavedPlace.fromJson(e)).toList();
  Future<SavedPlace> savePlace(String label, Place p) async =>
      SavedPlace.fromJson(await client.post('/me/places', {'label': label, 'address': p.address, 'lat': p.lat, 'lng': p.lng}));
  Future<void> deletePlace(String id) => client.delete('/me/places/$id');

  // ---- Rides (passenger) ----
  Future<List<ServiceQuote>> estimate(Place pickup, Place dropoff, {String? coupon}) async =>
      (await client.post('/rides/estimate', {'pickup': pickup.toJson(), 'dropoff': dropoff.toJson(), 'couponCode': coupon}) as List)
          .map((e) => ServiceQuote.fromJson(e))
          .toList();

  Future<Ride> requestRide({
    required String serviceId,
    required Place pickup,
    required Place dropoff,
    required PaymentMethod payment,
    double? offeredFare,
    String? coupon,
    String? note,
  }) async =>
      Ride.fromJson(await client.post('/rides', {
        'serviceId': serviceId,
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
        'paymentMethod': enumToApi(payment),
        'offeredFare': offeredFare,
        'couponCode': coupon,
        'note': note,
      }));

  Future<Ride?> currentRide() async {
    final j = await client.get('/rides/current');
    return j == null ? null : Ride.fromJson(j);
  }

  Future<Ride> ride(String id) async => Ride.fromJson(await client.get('/rides/$id'));

  Future<Paged<Ride>> rides({String? filter, int page = 1}) async {
    final j = await client.get('/rides', query: {'filter': filter, 'page': '$page'});
    return Paged((j['items'] as List).map((e) => Ride.fromJson(e)).toList(), j['total']);
  }

  Future<List<Bid>> bids(String rideId) async => (await client.get('/rides/$rideId/bids') as List).map((e) => Bid.fromJson(e)).toList();
  Future<Ride> acceptBid(String bidId) async => Ride.fromJson(await client.post('/rides/bids/$bidId/accept'));
  Future<void> declineBid(String bidId) => client.post('/rides/bids/$bidId/decline');
  Future<Ride> cancelRide(String id, {String? reason}) async => Ride.fromJson(await client.post('/rides/$id/cancel', {'reason': reason}));
  Future<Ride> pay(String id, PaymentMethod method, {double? tip}) async =>
      Ride.fromJson(await client.post('/rides/$id/pay', {'method': enumToApi(method), 'tip': tip}));
  Future<void> rate(String id, int stars, {String? comment, double? tip}) => client.post('/rides/$id/rate', {'stars': stars, 'comment': comment, 'tip': tip});
  Future<void> sos(String id, {double? lat, double? lng, String? message}) => client.post('/rides/$id/sos', {'lat': lat, 'lng': lng, 'message': message});
  Future<List<ChatMessage>> messages(String id) async => (await client.get('/rides/$id/messages') as List).map((e) => ChatMessage.fromJson(e)).toList();
  Future<ChatMessage> sendMessage(String id, String text) async => ChatMessage.fromJson(await client.post('/rides/$id/messages', {'text': text}));

  // ---- Wallet ----
  Future<WalletSummary> wallet() async => WalletSummary.fromJson(await client.get('/wallet'));
  Future<WalletSummary> topUp(double amount, PaymentMethod method) async =>
      WalletSummary.fromJson(await client.post('/wallet/top-up', {'amount': amount, 'method': enumToApi(method)}));

  // ---- Services ----
  Future<List<ServiceInfo>> services() async => (await client.get('/services') as List).map((e) => ServiceInfo.fromJson(e)).toList();

  // ---- Driver ----
  Future<DriverProfile> driverProfile() async => DriverProfile.fromJson(await client.get('/driver/profile'));
  Future<DriverProfile> saveVehicle({
    required String serviceId,
    String? licenceNumber,
    required String make,
    required String model,
    required String color,
    required int year,
    required String plate,
  }) async =>
      DriverProfile.fromJson(await client.put('/driver/vehicle', {
        'serviceId': serviceId,
        'licenceNumber': licenceNumber,
        'vehicleMake': make,
        'vehicleModel': model,
        'vehicleColor': color,
        'vehicleYear': year,
        'plateNumber': plate,
      }));
  Future<DriverProfile> uploadDocument(DocumentType type, List<int> bytes, String name) async =>
      DriverProfile.fromJson(await client.upload('/driver/documents/${enumToApi(type)}', 'file', bytes, name));
  Future<DriverProfile> submitForReview() async => DriverProfile.fromJson(await client.post('/driver/submit'));
  Future<void> setOnline(bool online, {double? lat, double? lng, double? heading}) =>
      client.post('/driver/online', {'online': online, 'location': lat == null ? null : {'lat': lat, 'lng': lng, 'heading': heading}});
  Future<void> sendLocation(double lat, double lng, {double? heading}) => client.post('/driver/location', {'lat': lat, 'lng': lng, 'heading': heading});
  Future<List<RideRequest>> openRequests() async => (await client.get('/driver/requests') as List).map((e) => RideRequest.fromJson(e)).toList();
  Future<Bid> placeBid(String rideId, double amount) async => Bid.fromJson(await client.post('/driver/requests/$rideId/bid', {'amount': amount}));
  Future<void> withdrawBid(String rideId) => client.delete('/driver/requests/$rideId/bid');
  Future<Ride> arrived(String rideId) async => Ride.fromJson(await client.post('/driver/rides/$rideId/arrived'));
  Future<Ride> startTrip(String rideId, String code) async => Ride.fromJson(await client.post('/driver/rides/$rideId/start', {'code': code}));
  Future<Ride> endTrip(String rideId) async => Ride.fromJson(await client.post('/driver/rides/$rideId/end'));
  Future<Ride> cashReceived(String rideId) async => Ride.fromJson(await client.post('/driver/rides/$rideId/cash-received'));
  Future<Earnings> earnings() async => Earnings.fromJson(await client.get('/driver/earnings'));
  Future<List<Withdrawal>> withdrawals() async => (await client.get('/driver/withdrawals') as List).map((e) => Withdrawal.fromJson(e)).toList();
  Future<Withdrawal> withdraw(double amount, String method, String account) async =>
      Withdrawal.fromJson(await client.post('/driver/withdrawals', {'amount': amount, 'method': method, 'accountNumber': account}));
}
