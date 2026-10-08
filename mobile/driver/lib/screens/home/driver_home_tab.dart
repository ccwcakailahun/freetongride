import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/driver_controller.dart';
import '../trip/driver_trip_screen.dart';

/// Map with the driver's position, the online switch, today's numbers, and incoming requests.
class DriverHomeTab extends StatefulWidget {
  const DriverHomeTab({super.key});

  @override
  State<DriverHomeTab> createState() => _DriverHomeTabState();
}

class _DriverHomeTabState extends State<DriverHomeTab> {
  Earnings? _earnings;
  bool _switching = false;
  bool _tripOpen = false;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      final e = await context.read<Session>().api.earnings();
      if (mounted) setState(() => _earnings = e);
    } catch (_) {}
  }

  Future<void> _toggle(bool value) async {
    setState(() => _switching = true);
    try {
      await context.read<DriverController>().setOnline(value);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _openTrip() async {
    _tripOpen = true;
    await go(context, const DriverTripScreen());
    _tripOpen = false;
    _loadEarnings();
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.watch<DriverController>();
    final user = context.watch<Session>().user!;
    if (dc.onTrip && !_tripOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _tripOpen ? null : _openTrip());
    final pos = dc.position ?? FreetownPlaces.centre;

    return Stack(children: [
      Positioned.fill(
        child: FtrMap(
          key: ValueKey(dc.position == null),
          center: pos,
          zoom: 15,
          markers: [
            if (dc.position != null) carMarker(pos, heading: dc.heading, size: 52),
            for (final r in dc.requests) pickupPin(LatLng(r.pickup.lat, r.pickup.lng)),
          ],
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Column(children: [
            FtrCard(
              radius: 26,
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(children: [
                FtrAvatar(name: user.fullName, photoUrl: context.read<Session>().client.absolute(user.photoUrl), size: 54, online: dc.online),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greeting(), style: FtrText.small),
                    Text(firstName(user.fullName), style: FtrText.h3.copyWith(fontSize: 19)),
                  ]),
                ),
                _OnlineSwitch(online: dc.online, busy: _switching, onChanged: _toggle),
              ]),
            ),
            const SizedBox(height: 10),
            FtrCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: IntrinsicHeight(
                child: Row(children: [
                  _Stat(label: 'Today', value: le(_earnings?.today ?? 0), color: FtrColors.green),
                  const VerticalDivider(width: 1),
                  _Stat(label: 'Trips', value: '${_earnings?.tripsToday ?? 0}'),
                  const VerticalDivider(width: 1),
                  _Stat(label: 'Rating', value: '★ ${user.rating.toStringAsFixed(1)}'),
                ]),
              ),
            ),
          ]),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _BottomPanel(dc: dc, switching: _switching, onGoOnline: () => _toggle(true)),
      ),
    ]);
  }
}

class _OnlineSwitch extends StatelessWidget {
  const _OnlineSwitch({required this.online, required this.busy, required this.onChanged});
  final bool online;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : () => onChanged(!online),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 116,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: online ? FtrColors.green : const Color(0xFFE4E8F0), borderRadius: BorderRadius.circular(22)),
        child: Stack(children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            alignment: online ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: busy
                  ? const Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2.2))
                  : Icon(Icons.power_settings_new_rounded, color: online ? FtrColors.green : FtrColors.muted, size: 22),
            ),
          ),
          Align(
            alignment: online ? const Alignment(-0.55, 0) : const Alignment(0.55, 0),
            child: Text(online ? 'Online' : 'Offline', style: FtrText.label.copyWith(color: online ? Colors.white : FtrColors.body)),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: FtrText.h3.copyWith(fontSize: 18, color: color)),
          Text(label, style: FtrText.small),
        ]),
      );
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.dc, required this.switching, required this.onGoOnline});
  final DriverController dc;
  final bool switching;
  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.52;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x221A3C8C), blurRadius: 30, offset: Offset(0, -6))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: !dc.online
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Text('You are offline', style: FtrText.h2),
              const SizedBox(height: 4),
              Text('Go online to receive ride requests near you.', style: FtrText.bodyMuted, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              DriverButton(label: 'Go Online', icon: Icons.power_settings_new_rounded, loading: switching, onPressed: onGoOnline),
            ])
          : dc.requests.isEmpty
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const _Searching(),
                  const SizedBox(height: 10),
                  Text('Looking for passengers…', style: FtrText.h3),
                  const SizedBox(height: 4),
                  Text('Stay in busy areas like Lumley, Aberdeen and Central to get requests faster.', textAlign: TextAlign.center, style: FtrText.bodyMuted),
                ])
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('New requests', style: FtrText.h2),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: FtrColors.green, borderRadius: BorderRadius.circular(12)),
                      child: Text('${dc.requests.length}', style: FtrText.label.copyWith(color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: dc.requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => RequestCard(request: dc.requests[i]),
                    ),
                  ),
                ]),
    );
  }
}

class _Searching extends StatefulWidget {
  const _Searching();
  @override
  State<_Searching> createState() => _SearchingState();
}

class _SearchingState extends State<_Searching> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => LinearProgressIndicator(value: null, color: FtrColors.green, backgroundColor: FtrColors.greenSoft),
          ),
        ),
      );
}

/// Incoming request: passenger, pickup distance, route, offered fare; accept or offer more.
class RequestCard extends StatefulWidget {
  const RequestCard({super.key, required this.request});
  final RideRequest request;

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _busy = false;

  Future<void> _offer(double amount) async {
    setState(() => _busy = true);
    try {
      await context.read<DriverController>().bid(widget.request, amount);
      if (mounted) showToast(context, 'Offer of ${le(amount)} sent. Waiting for the passenger.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _counter() async {
    final r = widget.request;
    final amount = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Offer a different fare', style: FtrText.h2),
            Text('Passenger offered ${le(r.offeredFare)}. Higher offers may be declined.', style: FtrText.bodyMuted),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final add in [5, 10, 15, 20, 30])
                ActionChip(
                  label: Text('${le(r.offeredFare + add)}  (+$add)'),
                  onPressed: () => Navigator.pop(ctx, r.offeredFare + add),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (amount != null) _offer(amount);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final dc = context.read<DriverController>();
    final sent = r.myBid != null;
    return FtrCard(
      padding: const EdgeInsets.all(14),
      border: true,
      child: Column(children: [
        Row(children: [
          FtrAvatar(name: r.passengerName, photoUrl: context.read<Session>().client.absolute(r.passengerPhotoUrl), size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.passengerName, style: FtrText.title),
              Row(children: [
                const Icon(Icons.star_rounded, size: 16, color: FtrColors.star),
                Text(' ${r.passengerRating.toStringAsFixed(1)}  •  ${r.pickupDistanceKm.toStringAsFixed(1)} km to pickup', style: FtrText.small),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(le(r.offeredFare), style: FtrText.h2.copyWith(color: FtrColors.green, fontSize: 22)),
            Text(r.paymentMethod.label, style: FtrText.small),
          ]),
        ]),
        const SizedBox(height: 12),
        FtrRouteSummary(from: r.pickup.address, to: r.dropoff.address, dense: true, toCaption: '${r.distanceKm.toStringAsFixed(1)} km • ${r.durationMinutes} min trip'),
        const SizedBox(height: 12),
        if (sent)
          Row(children: [
            const Icon(Icons.hourglass_top_rounded, color: FtrColors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('Offer sent: ${le(r.myBid!)}. Waiting for the passenger.', style: FtrText.label)),
            TextButton(onPressed: () => dc.withdraw(r), child: const Text('Withdraw')),
          ])
        else
          Row(children: [
            IconButton.outlined(tooltip: 'Skip this request', onPressed: () => dc.dismiss(r), icon: const Icon(Icons.close_rounded, color: FtrColors.muted)),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: FtrChipButton(label: 'Offer more', onPressed: _busy ? null : _counter, color: FtrColors.blue)),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _busy
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)))
                  : FtrChipButton(label: 'Accept ${le(r.offeredFare)}', primary: true, color: FtrColors.green, onPressed: () => _offer(r.offeredFare)),
            ),
          ]),
      ]),
    );
  }
}
