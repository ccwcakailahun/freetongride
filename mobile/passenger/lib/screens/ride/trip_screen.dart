import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../state/ride_controller.dart';
import 'chat_sheet.dart';
import 'trip_complete_screen.dart';

/// Canvas 6 — Trip in progress. Also covers "driver on the way" and "driver arrived".
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _map = MapController();
  List<LatLng>? _route;
  RideStatus? _routeFor;
  bool _done = false;

  void _ensureRoute(Ride r, LatLng? driver) {
    final toPickup = r.status == RideStatus.driverAssigned || r.status == RideStatus.driverArrived;
    if (_routeFor == r.status) return;
    _routeFor = r.status;
    final from = toPickup ? (driver ?? LatLng(r.pickup.lat, r.pickup.lng)) : LatLng(r.pickup.lat, r.pickup.lng);
    final to = toPickup ? LatLng(r.pickup.lat, r.pickup.lng) : LatLng(r.dropoff.lat, r.dropoff.lng);
    context.read<PlacesService>().route(from, to).then((pts) {
      if (mounted) setState(() => _route = pts);
    });
  }

  int _minutesTo(LatLng? from, Place to, int fallback) {
    if (from == null) return fallback;
    final km = const Distance().as(LengthUnit.Meter, from, LatLng(to.lat, to.lng)) / 1000;
    return (km * Geo.roadFactor / Geo.kmh * 60).ceil().clamp(1, 180);
  }

  Future<void> _sos(Ride r) async {
    final ok = await confirmSheet(context,
        title: 'Send an SOS alert?',
        message: 'FreeTongRide safety team will see your trip and location right away. In danger, also call 999 or 112.',
        confirmLabel: 'Send SOS',
        destructive: true);
    if (!ok || !mounted) return;
    try {
      final p = await LocationService.current();
      if (!mounted) return;
      await context.read<Session>().api.sos(r.id, lat: p?.latitude, lng: p?.longitude, message: 'Passenger pressed SOS');
      if (mounted) showToast(context, 'SOS sent. Our safety team has your location.', icon: Icons.sos_rounded);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _cancel(RideController rc) async {
    final ok = await confirmSheet(context,
        title: 'Cancel your ride?', message: 'Your driver is already on the way.', confirmLabel: 'Cancel ride', cancelLabel: 'Keep my ride', destructive: true);
    if (!ok || !mounted) return;
    try {
      await rc.cancel('Passenger cancelled before pickup');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RideController>();
    final r = rc.ride;
    if (r == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if ((r.status == RideStatus.awaitingPayment || r.status == RideStatus.completed) && !_done) {
      _done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => go(context, TripCompleteScreen(ride: r), replace: true));
    }
    if (r.status == RideStatus.cancelled) return _Cancelled(ride: r);

    final driver = r.driver!;
    final driverPos = rc.driverPosition ?? (driver.lat == null ? null : LatLng(driver.lat!, driver.lng!));
    _ensureRoute(r, driverPos);
    final pickup = LatLng(r.pickup.lat, r.pickup.lng);
    final dropoff = LatLng(r.dropoff.lat, r.dropoff.lng);
    final toPickup = r.status != RideStatus.inProgress;
    final minutes = toPickup ? _minutesTo(driverPos, r.pickup, 5) : _minutesTo(driverPos ?? pickup, r.dropoff, r.durationMinutes);
    final (title, prefix) = switch (r.status) {
      RideStatus.driverAssigned => ('Driver on the way', 'Arriving in '),
      RideStatus.driverArrived => ('Your driver is here', 'Waiting at pickup'),
      _ => ('On your trip', 'Arriving in '),
    };
    final eta = DateTime.now().add(Duration(minutes: minutes));

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          bottom: MediaQuery.sizeOf(context).height * 0.42,
          child: FtrMap(
            controller: _map,
            fitPoints: [?driverPos, toPickup ? pickup : dropoff, if (!toPickup) pickup],
            padding: const EdgeInsets.fromLTRB(60, 190, 60, 70),
            route: _route,
            markers: [
              pickupPin(pickup, label: r.pickup.address, onTap: () {}),
              if (!toPickup) dropoffPin(dropoff, label: r.dropoff.address),
              if (driverPos != null) carMarker(driverPos, heading: rc.driverHeading),
            ],
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(children: [
                IconButton(tooltip: 'Back', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, size: 30, color: FtrColors.ink)),
                const Expanded(child: Center(child: FtrBrandHeader(size: FtrBrandSize.compact))),
                const FtrBellButton(hasUnread: false),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: FtrCard(
                radius: 24,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const FtrIconTile(Icons.directions_car_filled_rounded, size: 64, circle: true, iconSize: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: FtrText.h2.copyWith(fontSize: 24)),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: prefix),
                          if (r.status != RideStatus.driverArrived)
                            TextSpan(text: '$minutes minute${minutes == 1 ? '' : 's'}', style: FtrText.h3.copyWith(color: FtrColors.blue, fontSize: 18)),
                        ]),
                        style: FtrText.body.copyWith(fontSize: 17, color: FtrColors.muted),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.47,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scroll) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x221A3C8C), blurRadius: 30, offset: Offset(0, -6))],
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: FtrColors.border, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                _DriverRow(ride: r, unread: rc.unreadMessages),
                if (r.status != RideStatus.inProgress && r.pickupCode != null) ...[
                  const SizedBox(height: 16),
                  _PickupCode(code: r.pickupCode!),
                ],
                const SizedBox(height: 18),
                _Progress(ride: r, minutesLeft: minutes, eta: eta),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.ios_share_rounded,
                      label: 'Share trip',
                      onTap: () => SharePlus.instance.share(ShareParams(
                          text: "I'm riding with FreeTongRide: ${driver.fullName}, ${driver.vehicle}. "
                              'From ${r.pickup.address} to ${r.dropoff.address}. Trip ${r.code}.')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _ActionTile(icon: Icons.shield_rounded, label: 'Safety', color: FtrColors.blue, onTap: () => _sos(r))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: toPickup
                        ? _ActionTile(icon: Icons.close_rounded, label: 'Cancel', color: FtrColors.red, onTap: () => _cancel(rc))
                        : _ActionTile(icon: Icons.add_rounded, label: 'Add stop', onTap: () => showToast(context, 'Adding stops is coming soon.', icon: Icons.info_outline_rounded)),
                  ),
                ]),
                const SizedBox(height: 14),
                _SummaryStrip(ride: r),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.ride, required this.unread});
  final Ride ride;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final d = ride.driver!;
    final session = context.read<Session>();
    return Row(children: [
      FtrAvatar(name: d.fullName, photoUrl: session.client.absolute(d.photoUrl), size: 78, online: true),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.shortName, style: FtrText.h3.copyWith(fontSize: 20)),
          FtrRating(rating: d.rating, count: d.ratingCount, size: 14),
          const SizedBox(height: 2),
          Text(d.vehicle, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.bodyMuted.copyWith(fontSize: 14)),
        ]),
      ),
      _RoundAction(icon: Icons.call_rounded, color: FtrColors.green, tip: 'Call driver', onTap: () => launchUrl(Uri.parse('tel:${d.phone}'))),
      const SizedBox(width: 10),
      Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: _RoundAction(icon: Icons.chat_rounded, color: FtrColors.blue, tip: 'Message driver', onTap: () => showChatSheet(context)),
      ),
    ]);
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.color, required this.tip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.5),
        child: IconButton(tooltip: tip, onPressed: onTap, iconSize: 28, padding: const EdgeInsets.all(14), icon: Icon(icon, color: Colors.white)),
      );
}

class _PickupCode extends StatelessWidget {
  const _PickupCode({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: FtrColors.blueSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        const Icon(Icons.pin_rounded, color: FtrColors.blue, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your pickup code', style: FtrText.title),
            Text('Give it to your driver to start the trip.', style: FtrText.small),
          ]),
        ),
        Text(code.split('').join(' '), style: FtrText.h1.copyWith(fontSize: 24, color: FtrColors.blue, letterSpacing: 1)),
      ]),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.ride, required this.minutesLeft, required this.eta});
  final Ride ride;
  final int minutesLeft;
  final DateTime eta;

  @override
  Widget build(BuildContext context) {
    final r = ride;
    final started = r.status == RideStatus.inProgress;
    Widget dot({required bool done, required bool active}) => Container(
          width: active ? 40 : 30,
          height: active ? 40 : 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? FtrColors.green : (active ? Colors.white : const Color(0xFFE9EDF4)),
            border: active ? Border.all(color: FtrColors.blue.withValues(alpha: 0.25), width: 6) : null,
          ),
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : Center(
                  child: Container(
                    width: active ? 14 : 12,
                    height: active ? 14 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? Colors.white : const Color(0xFF9AA2B5),
                      border: active ? Border.all(color: FtrColors.blue, width: 4) : null,
                    ),
                  ),
                ),
        );
    return Column(children: [
      Row(children: [
        dot(done: started, active: !started),
        Expanded(child: Container(height: 3, color: started ? FtrColors.blue : const Color(0xFFE2E7F0))),
        dot(done: false, active: started),
        Expanded(child: Container(height: 3, color: const Color(0xFFE2E7F0))),
        dot(done: false, active: false),
      ]),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pickup', style: FtrText.title.copyWith(fontSize: 15)),
            Text(r.pickup.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small),
            Text(r.startedAt != null ? clock(r.startedAt!) : (r.status == RideStatus.driverArrived ? 'Driver waiting' : 'In $minutesLeft min'), style: FtrText.small),
          ]),
        ),
        Expanded(
          child: Column(children: [
            Text(started ? 'On the way' : 'Driver coming', style: FtrText.title.copyWith(fontSize: 15, color: FtrColors.blue)),
            Text(started ? '$minutesLeft min left' : '', style: FtrText.small.copyWith(color: FtrColors.blue)),
          ]),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Drop-off', style: FtrText.title.copyWith(fontSize: 15)),
            Text(r.dropoff.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small, textAlign: TextAlign.right),
            if (started) Text('ETA ${clock(eta)}', style: FtrText.small),
          ]),
        ),
      ]),
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color = FtrColors.blue});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FtrCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: onTap,
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 6),
          Text(label, style: FtrText.label.copyWith(fontSize: 15)),
        ]),
      );
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    Widget cell(IconData i, Color c, String label, String value) => Expanded(
          child: Row(children: [
            Icon(i, color: c, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: FtrText.small.copyWith(fontSize: 12)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.title.copyWith(fontSize: 14)),
              ]),
            ),
          ]),
        );
    return FtrCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: IntrinsicHeight(
        child: Row(children: [
          cell(Icons.location_on_rounded, FtrColors.blue, 'Destination', ride.dropoff.address),
          const VerticalDivider(width: 16),
          cell(Icons.account_balance_wallet_rounded, FtrColors.blue, 'Fare', le(ride.fareDue)),
          const VerticalDivider(width: 16),
          cell(ride.paymentMethod == PaymentMethod.cash ? Icons.payments_rounded : Icons.credit_card_rounded, FtrColors.blue, 'Payment', ride.paymentMethod.label),
        ]),
      ),
    );
  }
}

class _Cancelled extends StatelessWidget {
  const _Cancelled({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: FtrEmptyState(
              icon: Icons.cancel_rounded,
              title: 'This ride was cancelled',
              message: ride.cancelReason ?? 'The ride is no longer active.',
              action: FtrChipButton(
                label: 'Back to Home',
                primary: true,
                onPressed: () {
                  context.read<RideController>().clear();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ),
          ),
        ),
      );
}
