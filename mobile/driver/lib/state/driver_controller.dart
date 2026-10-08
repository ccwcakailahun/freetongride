import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:geolocator/geolocator.dart';

/// Driver state: profile/approval, online status, incoming requests, the active trip and location sharing.
class DriverController extends ChangeNotifier {
  DriverController(this.session) {
    _sub = session.realtime.events.listen(_onEvent);
  }

  final Session session;
  late final StreamSubscription<RealtimeEvent> _sub;
  StreamSubscription<Position>? _gps;
  Timer? _poll;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  DriverProfile? profile;
  bool online = false;
  LatLng? position;
  double heading = 0;
  List<RideRequest> requests = [];
  Ride? ride;
  final messages = <ChatMessage>[];
  int unreadMessages = 0;

  FtrApi get api => session.api;
  bool get approved => profile?.status == DriverStatus.approved;
  bool get onTrip => ride != null && ride!.status.isActive;

  Future<void> load() async {
    profile = await api.driverProfile();
    online = profile!.isOnline;
    try {
      ride = await api.currentRide();
    } catch (_) {}
    notifyListeners();
    if (online) {
      _startGps();
      refreshRequests();
    }
  }

  Future<void> reloadProfile() async {
    profile = await api.driverProfile();
    notifyListeners();
  }

  Future<void> setOnline(bool value) async {
    if (value) {
      if (!await LocationService.request()) throw ApiException('Allow location so passengers near you can find you.');
      final p = await LocationService.current();
      if (p == null) throw ApiException('We could not get your location. Move to an open area and try again.');
      position = LatLng(p.latitude, p.longitude);
      await api.setOnline(true, lat: p.latitude, lng: p.longitude, heading: p.heading);
      online = true;
      _startGps();
      await refreshRequests();
    } else {
      await api.setOnline(false);
      online = false;
      requests = [];
      _stopGps();
    }
    notifyListeners();
  }

  Future<void> refreshRequests() async {
    if (!online || onTrip) return;
    try {
      requests = await api.openRequests();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> bid(RideRequest r, double amount) async {
    await api.placeBid(r.rideId, amount);
    await refreshRequests();
  }

  Future<void> withdraw(RideRequest r) async {
    await api.withdrawBid(r.rideId);
    await refreshRequests();
  }

  void dismiss(RideRequest r) {
    requests = requests.where((x) => x.rideId != r.rideId).toList();
    notifyListeners();
  }

  Future<void> arrived() async => _set(await api.arrived(ride!.id));
  Future<void> start(String code) async => _set(await api.startTrip(ride!.id, code));
  Future<void> end() async => _set(await api.endTrip(ride!.id));
  Future<void> cashReceived() async => _set(await api.cashReceived(ride!.id));

  Future<void> cancelTrip(String reason) async => _set(await api.cancelRide(ride!.id, reason: reason));

  Future<void> loadMessages() async {
    if (ride == null) return;
    messages
      ..clear()
      ..addAll(await api.messages(ride!.id));
    unreadMessages = 0;
    notifyListeners();
  }

  Future<void> send(String text) async {
    final m = await api.sendMessage(ride!.id, text);
    if (!messages.any((x) => x.id == m.id)) messages.add(m);
    notifyListeners();
  }

  /// Trip finished and was shown; go back to taking requests.
  void finishTrip() {
    ride = null;
    messages.clear();
    notifyListeners();
    refreshRequests();
  }

  void _set(Ride r) {
    ride = r;
    notifyListeners();
  }

  void _startGps() {
    _gps ??= LocationService.track(distanceFilter: 10).listen((p) {
      position = LatLng(p.latitude, p.longitude);
      heading = p.heading;
      notifyListeners();
      // At most one update every 4 seconds keeps data use low on Sierra Leone networks.
      if (DateTime.now().difference(_lastSent) > const Duration(seconds: 4)) {
        _lastSent = DateTime.now();
        api.sendLocation(p.latitude, p.longitude, heading: p.heading).catchError((_) {});
      }
    }, onError: (_) {});
    _poll ??= Timer.periodic(const Duration(seconds: 12), (_) {
      // Keeps the driver marked online and recovers requests missed while the socket was down.
      final pos = position;
      if (pos != null) api.sendLocation(pos.latitude, pos.longitude, heading: heading).catchError((_) {});
      if (!session.realtime.connected.value) refreshRequests();
    });
  }

  void _stopGps() {
    _gps?.cancel();
    _gps = null;
    _poll?.cancel();
    _poll = null;
  }

  void _onEvent(RealtimeEvent e) {
    switch (e.name) {
      case RideEvents.newRequest:
        if (!online || onTrip) return;
        final r = RideRequest.fromJson(e.data);
        requests = [r, ...requests.where((x) => x.rideId != r.rideId)];
        notifyListeners();
      case RideEvents.requestClosed || RideEvents.bidDeclined:
        requests = requests.where((x) => x.rideId != e.data['rideId']).toList();
        notifyListeners();
      case RideEvents.bidAccepted:
        ride = Ride.fromJson(e.data);
        requests = [];
        notifyListeners();
      case RideEvents.updated:
        final r = Ride.fromJson(e.data);
        if (ride != null && r.id == ride!.id) {
          ride = r;
          notifyListeners();
        }
      case RideEvents.message:
        final m = ChatMessage.fromJson(e.data);
        if (ride != null && m.rideId == ride!.id && !messages.any((x) => x.id == m.id)) {
          messages.add(m);
          if (m.senderId != session.user?.id) unreadMessages++;
          notifyListeners();
        }
      case RideEvents.driverReviewed:
        reloadProfile();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _stopGps();
    super.dispose();
  }
}
