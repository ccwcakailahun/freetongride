import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/ride_controller.dart';
import 'trip_screen.dart';

/// Searching: radar on the pickup, driver offers slide in; accept one to start.
class FindingDriverScreen extends StatefulWidget {
  const FindingDriverScreen({super.key});

  @override
  State<FindingDriverScreen> createState() => _FindingDriverScreenState();
}

class _FindingDriverScreenState extends State<FindingDriverScreen> with SingleTickerProviderStateMixin {
  late final _radar = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  String? _accepting;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    context.read<RideController>().refresh();
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  Future<void> _accept(Bid b) async {
    setState(() => _accepting = b.id);
    final rc = context.read<RideController>();
    try {
      await rc.accept(b);
    } catch (e) {
      if (mounted) showError(context, e);
      rc.refresh();
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmSheet(context,
        title: 'Cancel this request?', message: 'Drivers will stop seeing your request.', confirmLabel: 'Cancel request', cancelLabel: 'Keep looking', destructive: true);
    if (!ok || !mounted) return;
    try {
      await context.read<RideController>().cancel('Passenger cancelled while searching');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RideController>();
    final ride = rc.ride;
    if (ride != null && ride.status.hasDriver && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => go(context, const TripScreen(), replace: true));
    }
    if (ride == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (ride.status == RideStatus.cancelled) {
      return Scaffold(
        body: SafeArea(
          child: FtrEmptyState(
            icon: Icons.cancel_rounded,
            title: 'Request cancelled',
            message: ride.cancelReason ?? 'This request was cancelled.',
            action: FtrChipButton(label: 'Back to Home', primary: true, onPressed: () {
              rc.clear();
              Navigator.of(context).popUntil((r) => r.isFirst);
            }),
          ),
        ),
      );
    }
    final pickup = LatLng(ride.pickup.lat, ride.pickup.lng);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          bottom: MediaQuery.sizeOf(context).height * 0.42,
          child: Stack(children: [
            FtrMap(center: pickup, zoom: 15, markers: [pickupPin(pickup, label: ride.pickup.address)]),
            IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _radar,
                  builder: (_, _) => Stack(alignment: Alignment.center, children: [
                    for (final offset in [0.0, 0.33, 0.66])
                      Builder(builder: (_) {
                        final t = (_radar.value + offset) % 1;
                        return Container(
                          width: 60 + 260 * t,
                          height: 60 + 260 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FtrColors.blue.withValues(alpha: 0.16 * (1 - t)),
                            border: Border.all(color: FtrColors.blue.withValues(alpha: 0.35 * (1 - t)), width: 1.5),
                          ),
                        );
                      }),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: FtrCard(
              radius: 24,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const FtrIconTile(Icons.radar_rounded, size: 52, circle: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Finding your driver', style: FtrText.h3.copyWith(fontSize: 19)),
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: 'Your offer '),
                      TextSpan(text: le(ride.offeredFare), style: FtrText.title.copyWith(color: FtrColors.blue)),
                      TextSpan(text: ' • ${ride.serviceName}'),
                    ]), style: FtrText.bodyMuted),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.45,
          maxChildSize: 0.88,
          builder: (context, scroll) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x221A3C8C), blurRadius: 30, offset: Offset(0, -6))],
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: FtrColors.border, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Text(rc.bids.isEmpty ? 'Waiting for offers…' : 'Driver offers (${rc.bids.length})', style: FtrText.h2)),
                  if (rc.bids.isEmpty) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                ]),
                const SizedBox(height: 4),
                Text(
                  rc.bids.isEmpty
                      ? 'Nearby ${ride.serviceName} drivers are seeing your request. Offers usually arrive within a minute.'
                      : 'Pick the driver you prefer. Prices include the full trip.',
                  style: FtrText.bodyMuted,
                ),
                const SizedBox(height: 16),
                for (final b in rc.bids) ...[
                  _BidCard(
                    bid: b,
                    busy: _accepting == b.id,
                    onAccept: _accepting == null ? () => _accept(b) : null,
                    onDecline: _accepting == null ? () => rc.decline(b) : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (rc.bids.isEmpty)
                  FtrRouteSummary(from: ride.pickup.address, to: ride.dropoff.address, fromLabel: 'Pickup', toLabel: 'Drop-off'),
                const SizedBox(height: 18),
                FtrOutlineButton(label: 'Cancel request', icon: Icons.close_rounded, onPressed: _cancel),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _BidCard extends StatelessWidget {
  const _BidCard({required this.bid, required this.onAccept, required this.onDecline, this.busy = false});
  final Bid bid;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final d = bid.driver;
    final session = context.read<Session>();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.translate(offset: Offset(0, 24 * (1 - t)), child: Opacity(opacity: t.clamp(0, 1), child: child)),
      child: FtrCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            FtrAvatar(name: d.fullName, photoUrl: session.client.absolute(d.photoUrl), size: 62, online: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.shortName, style: FtrText.title.copyWith(fontSize: 17)),
                FtrRating(rating: d.rating, count: d.ratingCount, size: 13.5),
                Text(d.vehicle, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(le(bid.amount), style: FtrText.h2.copyWith(fontSize: 21, color: FtrColors.blue)),
              Text('${bid.etaMinutes} min away', style: FtrText.small.copyWith(color: FtrColors.green, fontWeight: FontWeight.w700)),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FtrChipButton(label: 'Decline', onPressed: onDecline, color: FtrColors.muted)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: busy
                  ? const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)))
                  : FtrChipButton(label: 'Accept ${le(bid.amount)}', icon: Icons.check_rounded, primary: true, onPressed: onAccept),
            ),
          ]),
        ]),
      ),
    );
  }
}
