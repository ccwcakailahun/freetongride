import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'api.dart';

class RealtimeEvent {
  RealtimeEvent(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
}

/// Event names pushed by the API (RideEvents in the backend).
abstract final class RideEvents {
  static const newRequest = 'ride.request';
  static const requestClosed = 'ride.request.closed';
  static const newBid = 'ride.bid';
  static const bidWithdrawn = 'ride.bid.withdrawn';
  static const bidAccepted = 'ride.bid.accepted';
  static const bidDeclined = 'ride.bid.declined';
  static const updated = 'ride.updated';
  static const driverLocation = 'ride.driver.location';
  static const message = 'ride.message';
  static const driverReviewed = 'driver.reviewed';
  static const withdrawalUpdated = 'withdrawal.updated';

  static const all = [newRequest, requestClosed, newBid, bidWithdrawn, bidAccepted, bidDeclined, updated, driverLocation, message, driverReviewed, withdrawalUpdated];
}

/// SignalR connection to /hubs/ride. Reconnects on its own; screens listen to [events].
class Realtime {
  Realtime(this.client);
  final ApiClient client;
  HubConnection? _hub;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final connected = ValueNotifier(false);

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<RealtimeEvent> on(String name) => events.where((e) => e.name == name);

  Future<void> connect() async {
    if (client.token == null) return;
    if (_hub != null && _hub!.state == HubConnectionState.Connected) return;
    final hub = HubConnectionBuilder()
        .withUrl('${client.baseUrl}/hubs/ride', options: HttpConnectionOptions(accessTokenFactory: () async => client.token ?? ''))
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000, 30000])
        .build();
    for (final name in RideEvents.all) {
      hub.on(name, (args) {
        final payload = args == null || args.isEmpty ? null : args.first;
        _events.add(RealtimeEvent(name, payload is Map ? Map<String, dynamic>.from(payload) : {'value': payload}));
      });
    }
    hub.onclose(({error}) => connected.value = false);
    hub.onreconnected(({connectionId}) => connected.value = true);
    hub.onreconnecting(({error}) => connected.value = false);
    _hub = hub;
    try {
      await hub.start();
      connected.value = true;
    } catch (e) {
      debugPrint('Realtime connect failed: $e');
      connected.value = false;
      // Retry in the background; REST polling covers the gap.
      Future.delayed(const Duration(seconds: 8), () {
        if (_hub == hub && !connected.value) {
          _hub = null;
          connect();
        }
      });
    }
  }

  Future<void> disconnect() async {
    final hub = _hub;
    _hub = null;
    connected.value = false;
    await hub?.stop();
  }
}
