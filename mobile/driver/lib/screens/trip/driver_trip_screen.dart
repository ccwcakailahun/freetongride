import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../state/driver_controller.dart';

/// One screen for the whole trip: to pickup → code → driving → payment → rate.
class DriverTripScreen extends StatefulWidget {
  const DriverTripScreen({super.key});

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  final _code = TextEditingController();
  List<LatLng>? _route;
  RideStatus? _routeFor;
  bool _busy = false;
  int _stars = 5;
  bool _rated = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _ensureRoute(Ride r, LatLng? me) {
    if (_routeFor == r.status) return;
    _routeFor = r.status;
    final toPickup = r.status == RideStatus.driverAssigned || r.status == RideStatus.driverArrived;
    final from = toPickup ? (me ?? LatLng(r.pickup.lat, r.pickup.lng)) : LatLng(r.pickup.lat, r.pickup.lng);
    final to = toPickup ? LatLng(r.pickup.lat, r.pickup.lng) : LatLng(r.dropoff.lat, r.dropoff.lng);
    context.read<PlacesService>().route(from, to).then((p) {
      if (mounted) setState(() => _route = p);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _navigate(Place p) => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving'), mode: LaunchMode.externalApplication);

  Future<void> _sos(Ride r) async {
    final ok = await confirmSheet(context,
        title: 'Send an SOS alert?', message: 'The FreeTongRide safety team will see this trip and your location right away.', confirmLabel: 'Send SOS', destructive: true);
    if (!ok || !mounted) return;
    final dc = context.read<DriverController>();
    await _run(() => dc.api.sos(r.id, lat: dc.position?.latitude, lng: dc.position?.longitude, message: 'Driver pressed SOS'));
    if (mounted) showToast(context, 'SOS sent. Our safety team has your location.', icon: Icons.sos_rounded);
  }

  Future<void> _cancel() async {
    final ok = await confirmSheet(context,
        title: 'Cancel this trip?', message: 'Cancelling often lowers your acceptance score.', confirmLabel: 'Cancel trip', cancelLabel: 'Keep trip', destructive: true);
    if (ok && mounted) await _run(() => context.read<DriverController>().cancelTrip('Driver cancelled before pickup'));
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.watch<DriverController>();
    final r = dc.ride;
    if (r == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    _ensureRoute(r, dc.position);
    final pickup = LatLng(r.pickup.lat, r.pickup.lng);
    final dropoff = LatLng(r.dropoff.lat, r.dropoff.lng);
    final toPickup = r.status == RideStatus.driverAssigned || r.status == RideStatus.driverArrived;

    return PopScope(
      canPop: !r.status.isActive,
      child: Scaffold(
        body: Stack(children: [
          Positioned.fill(
            bottom: MediaQuery.sizeOf(context).height * 0.4,
            child: FtrMap(
              fitPoints: [?dc.position, if (toPickup) pickup else dropoff, if (!toPickup) pickup],
              padding: const EdgeInsets.fromLTRB(50, 130, 60, 60),
              route: _route,
              markers: [
                pickupPin(pickup, label: r.pickup.address),
                if (!toPickup) dropoffPin(dropoff, label: r.dropoff.address),
                if (dc.position != null) carMarker(dc.position!, heading: dc.heading),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: FtrCard(
                radius: 24,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  FtrIconTile(_headerIcon(r.status), size: 56, circle: true, color: FtrColors.green, background: FtrColors.greenSoft),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_headerTitle(r), style: FtrText.h3.copyWith(fontSize: 19)),
                      Text(toPickup ? r.pickup.address : r.dropoff.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.bodyMuted),
                    ]),
                  ),
                  if (r.status.isActive && r.status != RideStatus.awaitingPayment)
                    IconButton.filled(
                      tooltip: 'Open in Google Maps',
                      style: IconButton.styleFrom(backgroundColor: FtrColors.blue),
                      onPressed: () => _navigate(toPickup ? r.pickup : r.dropoff),
                      icon: const Icon(Icons.navigation_rounded, color: Colors.white),
                    ),
                ]),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Color(0x221A3C8C), blurRadius: 30, offset: Offset(0, -6))],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    _PassengerRow(ride: r, unread: dc.unreadMessages, onSos: () => _sos(r)),
                    const SizedBox(height: 16),
                    ..._stage(r, dc),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _stage(Ride r, DriverController dc) {
    switch (r.status) {
      case RideStatus.driverAssigned:
        return [
          _FareLine(ride: r),
          const SizedBox(height: 16),
          DriverButton(label: "I've arrived", icon: Icons.place_rounded, loading: _busy, onPressed: () => _run(dc.arrived)),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: _cancel, child: Text('Cancel trip', style: FtrText.label.copyWith(color: FtrColors.red)))),
        ];
      case RideStatus.driverArrived:
        return [
          Text('Ask ${firstName(r.passenger.fullName)} for the 6-digit pickup code', textAlign: TextAlign.center, style: FtrText.title.copyWith(fontSize: 16.5)),
          const SizedBox(height: 14),
          FtrCodeInput(controller: _code, onCompleted: (c) => _run(() => dc.start(c))),
          const SizedBox(height: 16),
          DriverButton(label: 'Start trip', loading: _busy, onPressed: () => _run(() => dc.start(_code.text))),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: _cancel, child: Text('Passenger not here? Cancel', style: FtrText.label.copyWith(color: FtrColors.red)))),
        ];
      case RideStatus.inProgress:
        return [
          FtrRouteSummary(from: r.pickup.address, to: r.dropoff.address, fromLabel: 'Picked up', toLabel: 'Drop-off'),
          const SizedBox(height: 14),
          _FareLine(ride: r),
          const SizedBox(height: 16),
          DriverButton(
            label: 'End trip',
            icon: Icons.flag_rounded,
            showArrow: false,
            loading: _busy,
            onPressed: () async {
              final ok = await confirmSheet(context, title: 'End the trip here?', message: 'Only end the trip once ${firstName(r.passenger.fullName)} has arrived.', confirmLabel: 'End trip');
              if (ok) _run(dc.end);
            },
          ),
        ];
      case RideStatus.awaitingPayment:
        final cash = r.paymentMethod == PaymentMethod.cash;
        return [
          Text(cash ? 'Collect cash' : 'Waiting for payment', textAlign: TextAlign.center, style: FtrText.h2),
          const SizedBox(height: 4),
          Text(le(r.fareDue + (r.tip ?? 0)), textAlign: TextAlign.center, style: FtrText.display.copyWith(fontSize: 44, color: FtrColors.green)),
          Text(cash ? 'Take the cash from ${firstName(r.passenger.fullName)}, then confirm.' : '${firstName(r.passenger.fullName)} is paying from their wallet.',
              textAlign: TextAlign.center, style: FtrText.bodyMuted),
          const SizedBox(height: 16),
          if (cash)
            DriverButton(label: 'Cash received', icon: Icons.payments_rounded, showArrow: false, loading: _busy, onPressed: () => _run(dc.cashReceived))
          else
            const Center(child: CircularProgressIndicator(color: FtrColors.green)),
        ];
      case RideStatus.completed:
        final commission = r.commission ?? 0;
        return [
          const Center(child: Icon(Icons.check_circle_rounded, color: FtrColors.green, size: 64)),
          Text('Trip complete', textAlign: TextAlign.center, style: FtrText.h1),
          const SizedBox(height: 12),
          FtrCard(
            child: Column(children: [
              _line('Fare', le(r.fareDue)),
              if ((r.tip ?? 0) > 0) _line('Tip', le(r.tip!)),
              _line('FreeTongRide commission', '- ${le(commission)}', color: FtrColors.red),
              const Divider(height: 20),
              _line('You earned', le(r.fareDue + (r.tip ?? 0) - commission), bold: true),
            ]),
          ),
          const SizedBox(height: 14),
          if (!_rated) ...[
            Text('Rate ${firstName(r.passenger.fullName)}', textAlign: TextAlign.center, style: FtrText.title),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(Icons.star_rounded, size: 36, color: i <= _stars ? FtrColors.star : const Color(0xFFDDE2EA)),
                ),
            ]),
          ],
          DriverButton(
            label: _rated ? 'Back to requests' : 'Submit & continue',
            loading: _busy,
            onPressed: () async {
              if (!_rated) {
                await _run(() => dc.api.rate(r.id, _stars));
                _rated = true;
              }
              dc.finishTrip();
              if (mounted) Navigator.pop(context);
            },
          ),
        ];
      case RideStatus.cancelled:
        return [
          const Center(child: Icon(Icons.cancel_rounded, color: FtrColors.red, size: 60)),
          Text('Trip cancelled', textAlign: TextAlign.center, style: FtrText.h2),
          Text(r.cancelReason ?? '', textAlign: TextAlign.center, style: FtrText.bodyMuted),
          const SizedBox(height: 16),
          DriverButton(
            label: 'Back to requests',
            onPressed: () {
              dc.finishTrip();
              Navigator.pop(context);
            },
          ),
        ];
      case RideStatus.searching:
        return [const Center(child: CircularProgressIndicator())];
    }
  }

  Widget _line(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: bold ? FtrText.title.copyWith(fontSize: 17) : FtrText.body.copyWith(color: FtrColors.muted))),
          Text(value, style: bold ? FtrText.h3.copyWith(color: FtrColors.green) : FtrText.label.copyWith(color: color)),
        ]),
      );

  IconData _headerIcon(RideStatus s) => switch (s) {
        RideStatus.driverAssigned => Icons.directions_car_filled_rounded,
        RideStatus.driverArrived => Icons.place_rounded,
        RideStatus.inProgress => Icons.route_rounded,
        RideStatus.awaitingPayment => Icons.payments_rounded,
        _ => Icons.flag_rounded,
      };

  String _headerTitle(Ride r) => switch (r.status) {
        RideStatus.driverAssigned => 'Pick up ${firstName(r.passenger.fullName)}',
        RideStatus.driverArrived => 'Waiting at pickup',
        RideStatus.inProgress => 'Driving to drop-off',
        RideStatus.awaitingPayment => 'Collect payment',
        RideStatus.completed => 'Trip complete',
        _ => 'Trip',
      };
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({required this.ride, required this.unread, required this.onSos});
  final Ride ride;
  final int unread;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final p = ride.passenger;
    final active = ride.status.isActive;
    return Row(children: [
      FtrAvatar(name: p.fullName, photoUrl: context.read<Session>().client.absolute(p.photoUrl), size: 58),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.fullName, style: FtrText.title.copyWith(fontSize: 17)),
          FtrRating(rating: p.rating, size: 13),
          Text('${ride.serviceName} • ${ride.code}', style: FtrText.small),
        ]),
      ),
      if (active) ...[
        _Round(icon: Icons.call_rounded, color: FtrColors.green, tip: 'Call passenger', onTap: () => launchUrl(Uri.parse('tel:${p.phone}'))),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: _Round(icon: Icons.chat_rounded, color: FtrColors.blue, tip: 'Message passenger', onTap: () => _chat(context)),
        ),
        const SizedBox(width: 8),
        _Round(icon: Icons.sos_rounded, color: FtrColors.red, tip: 'Safety', onTap: onSos),
      ],
    ]);
  }

  void _chat(BuildContext context) {
    final dc = context.read<DriverController>()..loadMessages();
    final text = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: dc,
        child: Consumer<DriverController>(
          builder: (ctx, dc, _) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.6,
              child: Column(children: [
                Text('Chat with ${firstName(ride.passenger.fullName)}', style: FtrText.h2),
                Expanded(
                  child: ListView(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final m in dc.messages.reversed)
                        Align(
                          alignment: m.senderId == dc.session.user!.id ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: m.senderId == dc.session.user!.id ? FtrColors.green : const Color(0xFFF0F3F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(m.text, style: FtrText.body.copyWith(color: m.senderId == dc.session.user!.id ? Colors.white : FtrColors.ink)),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    for (final q in ["I'm on my way", "I've arrived", 'I am in a white car', 'Traffic is heavy, 5 min'])
                      Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(q), onPressed: () => dc.send(q))),
                  ]),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Row(children: [
                      Expanded(child: FtrPlainField(hint: 'Type a message', controller: text, height: 56)),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: FtrColors.green),
                        onPressed: () {
                          if (text.text.trim().isEmpty) return;
                          dc.send(text.text.trim()).catchError((e) {
                            if (ctx.mounted) showError(ctx, e);
                          });
                          text.clear();
                        },
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.color, required this.tip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: const CircleBorder(),
        child: IconButton(tooltip: tip, onPressed: onTap, icon: Icon(icon, color: Colors.white)),
      );
}

class _FareLine extends StatelessWidget {
  const _FareLine({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) => FtrCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(ride.paymentMethod == PaymentMethod.cash ? Icons.payments_rounded : Icons.account_balance_wallet_rounded, color: FtrColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text('${ride.paymentMethod.label} • ${ride.distanceKm.toStringAsFixed(1)} km', style: FtrText.label)),
          Text(le(ride.fareDue), style: FtrText.h3.copyWith(color: FtrColors.green)),
        ]),
      );
}
