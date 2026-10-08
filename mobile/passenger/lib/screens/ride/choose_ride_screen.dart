import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/ride_controller.dart';
import 'finding_driver_screen.dart';

/// Route on the map, ride types with fares, payment, your offer, then Request.
class ChooseRideScreen extends StatefulWidget {
  const ChooseRideScreen({super.key, required this.pickup, required this.dropoff, this.forSomeoneElse = false});
  final Place pickup;
  final Place dropoff;
  final bool forSomeoneElse;

  @override
  State<ChooseRideScreen> createState() => _ChooseRideScreenState();
}

class _ChooseRideScreenState extends State<ChooseRideScreen> {
  List<ServiceQuote>? _quotes;
  ServiceQuote? _selected;
  List<LatLng>? _route;
  PaymentMethod _payment = PaymentMethod.cash;
  double? _offer;
  String? _coupon;
  Object? _error;
  bool _busy = false;

  LatLng get _from => LatLng(widget.pickup.lat, widget.pickup.lng);
  LatLng get _to => LatLng(widget.dropoff.lat, widget.dropoff.lng);

  @override
  void initState() {
    super.initState();
    _load();
    context.read<PlacesService>().route(_from, _to).then((r) {
      if (mounted) setState(() => _route = r);
    });
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final q = await context.read<Session>().api.estimate(widget.pickup, widget.dropoff, coupon: _coupon);
      if (!mounted) return;
      setState(() {
        _quotes = q;
        _selected = q.where((x) => x.serviceId == _selected?.serviceId).firstOrNull ??
            q.where((x) => x.driversNearby > 0).firstOrNull ??
            q.firstOrNull;
        _offer = _selected?.fare;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _promo() async {
    final c = TextEditingController(text: _coupon);
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Promo code', style: FtrText.h2),
          const SizedBox(height: 14),
          FtrPlainField(hint: 'e.g. WELCOME10', icon: Icons.local_offer_outlined, controller: c),
          const SizedBox(height: 16),
          FtrPrimaryButton(label: 'Apply', showArrow: false, onPressed: () => Navigator.pop(ctx, c.text.trim().toUpperCase())),
        ]),
      ),
    );
    if (code == null) return;
    setState(() => _coupon = code.isEmpty ? null : code);
    _load();
  }

  Future<void> _request() async {
    final s = _selected;
    if (s == null) return;
    setState(() => _busy = true);
    try {
      final ride = await context.read<Session>().api.requestRide(
            serviceId: s.serviceId,
            pickup: widget.pickup,
            dropoff: widget.dropoff,
            payment: _payment,
            offeredFare: _offer,
            coupon: _coupon,
          );
      if (!mounted) return;
      context.read<RideController>().start(ride);
      go(context, const FindingDriverScreen(), replace: true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          bottom: MediaQuery.sizeOf(context).height * 0.45,
          child: FtrMap(
            fitPoints: [_from, _to],
            padding: const EdgeInsets.fromLTRB(50, 120, 50, 50),
            route: _route,
            markers: [pickupPin(_from, label: widget.pickup.address), dropoffPin(_to, label: widget.dropoff.address)],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(color: Colors.white, shape: const CircleBorder(), elevation: 3, child: const FtrBackButton()),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.58,
          minChildSize: 0.5,
          maxChildSize: 0.9,
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
                Text('Choose a ride', style: FtrText.h2),
                if (_quotes != null && _quotes!.isNotEmpty)
                  Text('${_quotes!.first.distanceKm.toStringAsFixed(1)} km • about ${_quotes!.first.durationMinutes} min', style: FtrText.bodyMuted),
                const SizedBox(height: 14),
                if (_error != null)
                  FtrEmptyState(icon: Icons.wifi_off_rounded, title: 'Could not get prices', message: '$_error', action: FtrChipButton(label: 'Try again', onPressed: _load))
                else if (_quotes == null)
                  const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                else
                  for (final q in _quotes!) ...[
                    _QuoteTile(
                      quote: q,
                      selected: q.serviceId == _selected?.serviceId,
                      onTap: () => setState(() {
                        _selected = q;
                        _offer = q.fare;
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (_selected != null) ...[
                  const SizedBox(height: 6),
                  _OfferStepper(
                    value: _offer ?? _selected!.fare,
                    min: (_selected!.fare * 0.7).floorToDouble(),
                    max: _selected!.fare * 2,
                    onChanged: (v) => setState(() => _offer = v),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _PaymentPicker(value: _payment, onChanged: (m) => setState(() => _payment = m)),
                    ),
                    const SizedBox(width: 10),
                    FtrChipButton(label: _coupon ?? 'Promo', icon: Icons.local_offer_outlined, onPressed: _promo, height: 54),
                  ]),
                  const SizedBox(height: 18),
                  FtrPrimaryButton(
                    label: 'Request ${_selected!.name} • ${le((_offer ?? _selected!.fare) - _selected!.discount)}',
                    loading: _busy,
                    onPressed: _request,
                  ),
                  if (_selected!.driversNearby == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('No ${_selected!.name} drivers online nearby right now. You can still request; we will keep looking.',
                          textAlign: TextAlign.center, style: FtrText.small),
                    ),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

IconData serviceIcon(String name) => switch (name.toLowerCase()) {
      'okada' => Icons.two_wheeler_rounded,
      'keke' => Icons.electric_rickshaw_rounded,
      _ => Icons.directions_car_filled_rounded,
    };

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote, required this.selected, required this.onTap});
  final ServiceQuote quote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? FtrColors.blueSoft.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? FtrColors.blue : FtrColors.border, width: selected ? 1.8 : 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            child: Row(children: [
              FtrIconTile(serviceIcon(q.name), size: 56, background: selected ? Colors.white : FtrColors.blueSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(q.name, style: FtrText.title.copyWith(fontSize: 17)),
                    const SizedBox(width: 8),
                    const Icon(Icons.person_rounded, size: 16, color: FtrColors.muted),
                    Text('${q.seats}', style: FtrText.small),
                  ]),
                  Text(
                    q.nearestDriverMinutes == null ? q.description : '${q.nearestDriverMinutes} min away • ${q.driversNearby} nearby',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FtrText.small.copyWith(color: q.nearestDriverMinutes == null ? FtrColors.muted : FtrColors.green, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(le(q.fare - q.discount), style: FtrText.h3.copyWith(fontSize: 18)),
                if (q.discount > 0) Text(le(q.fare), style: FtrText.small.copyWith(decoration: TextDecoration.lineThrough)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Lets the passenger raise their offer to attract drivers faster, or lower it a little.
class _OfferStepper extends StatelessWidget {
  const _OfferStepper({required this.value, required this.min, required this.max, required this.onChanged});
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = value >= 100 ? 10.0 : 5.0;
    Widget btn(IconData i, double next, String tip) => Material(
          color: FtrColors.blueSoft,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tip,
            onPressed: next < min || next > max ? null : () => onChanged(next),
            icon: Icon(i, color: FtrColors.blue),
          ),
        );
    return FtrCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your offer', style: FtrText.small),
            Text(le(value), style: FtrText.h2.copyWith(fontSize: 22)),
          ]),
        ),
        btn(Icons.remove_rounded, value - step, 'Lower offer'),
        const SizedBox(width: 8),
        btn(Icons.add_rounded, value + step, 'Raise offer'),
      ]),
    );
  }
}

class _PaymentPicker extends StatelessWidget {
  const _PaymentPicker({required this.value, required this.onChanged});
  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF1F4FA), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        for (final m in [PaymentMethod.cash, PaymentMethod.wallet])
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: value == m ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: value == m ? ftrSoftShadow : null,
                ),
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(m == PaymentMethod.cash ? Icons.payments_rounded : Icons.account_balance_wallet_rounded,
                      size: 20, color: value == m ? (m == PaymentMethod.cash ? FtrColors.green : FtrColors.blue) : FtrColors.muted),
                  const SizedBox(width: 6),
                  Text(m.label, style: FtrText.label.copyWith(color: value == m ? FtrColors.ink : FtrColors.muted)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
