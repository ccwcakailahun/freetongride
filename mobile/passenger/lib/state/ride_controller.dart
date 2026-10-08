import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ftr_core/ftr_core.dart';

/// Holds the passenger's live ride: offers while searching, driver position during the trip.
/// Listens to realtime events and polls as a fallback when the socket is down.
class RideController extends ChangeNotifier {
  RideController(this.session) {
    _sub = session.realtime.events.listen(_onEvent);
  }

  final Session session;
  late final StreamSubscription<RealtimeEvent> _sub;
  Timer? _poll;

  Ride? ride;
  List<Bid> bids = [];
  LatLng? driverPosition;
  double driverHeading = 0;
  final messages = <ChatMessage>[];
  int unreadMessages = 0;

  FtrApi get api => session.api;
  bool get hasActiveRide => ride != null && ride!.status.isActive;

  Future<Ride?> loadCurrent() async {
    try {
      ride = await api.currentRide();
    } catch (_) {}
    _afterRideChange();
    return ride;
  }

  void start(Ride r) {
    ride = r;
    bids = [];
    messages.clear();
    unreadMessages = 0;
    _afterRideChange();
  }

  Future<void> refresh() async {
    final r = ride;
    if (r == null) return;
    try {
      ride = await api.ride(r.id);
      if (ride!.status == RideStatus.searching) bids = await api.bids(r.id);
    } catch (_) {}
    _afterRideChange();
  }

  Future<Ride> accept(Bid bid) async {
    final r = await api.acceptBid(bid.id);
    ride = r;
    bids = [];
    _afterRideChange();
    return r;
  }

  Future<void> decline(Bid bid) async {
    await api.declineBid(bid.id);
    bids.removeWhere((b) => b.id == bid.id);
    notifyListeners();
  }

  Future<void> cancel(String? reason) async {
    final r = ride;
    if (r == null) return;
    ride = await api.cancelRide(r.id, reason: reason);
    _afterRideChange();
  }

  Future<void> loadMessages() async {
    final r = ride;
    if (r == null) return;
    final list = await api.messages(r.id);
    messages
      ..clear()
      ..addAll(list);
    unreadMessages = 0;
    notifyListeners();
  }

  Future<void> send(String text) async {
    final r = ride;
    if (r == null) return;
    final m = await api.sendMessage(r.id, text);
    if (!messages.any((x) => x.id == m.id)) messages.add(m);
    notifyListeners();
  }

  /// Ride finished and was shown; forget it so Home is clean.
  void clear() {
    ride = null;
    bids = [];
    driverPosition = null;
    _afterRideChange();
  }

  void _afterRideChange() {
    final d = ride?.driver;
    if (d?.lat != null && driverPosition == null) driverPosition = LatLng(d!.lat!, d.lng!);
    _poll?.cancel();
    if (hasActiveRide) {
      _poll = Timer.periodic(Duration(seconds: ride!.status == RideStatus.searching ? 6 : 10), (_) {
        if (!session.realtime.connected.value) refresh();
      });
    }
    notifyListeners();
  }

  void _onEvent(RealtimeEvent e) {
    final r = ride;
    switch (e.name) {
      case RideEvents.newBid:
        final bid = Bid.fromJson(e.data);
        if (r != null && bid.rideId == r.id) {
          bids = [...bids.where((b) => b.id != bid.id), bid]..sort((a, b) => a.amount.compareTo(b.amount));
          notifyListeners();
        }
      case RideEvents.bidWithdrawn:
        bids.removeWhere((b) => b.id == e.data['bidId']);
        notifyListeners();
      case RideEvents.updated:
        final updated = Ride.fromJson(e.data);
        if (r == null || updated.id == r.id) {
          ride = updated;
          _afterRideChange();
        }
      case RideEvents.driverLocation:
        if (r != null && e.data['rideId'] == r.id) {
          driverPosition = LatLng((e.data['lat'] as num).toDouble(), (e.data['lng'] as num).toDouble());
          driverHeading = (e.data['heading'] as num?)?.toDouble() ?? driverHeading;
          notifyListeners();
        }
      case RideEvents.message:
        final m = ChatMessage.fromJson(e.data);
        if (r != null && m.rideId == r.id && !messages.any((x) => x.id == m.id)) {
          messages.add(m);
          if (m.senderId != session.user?.id) unreadMessages++;
          notifyListeners();
        }
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _poll?.cancel();
    super.dispose();
  }
}
