import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../main.dart';
import '../../state/ride_controller.dart';
import 'choose_ride_screen.dart';

/// Canvas 7 — Trip completed. Also the receipt view from Activity.
class TripCompleteScreen extends StatefulWidget {
  const TripCompleteScreen({super.key, required this.ride, this.fromHistory = false});
  final Ride ride;
  final bool fromHistory;

  @override
  State<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends State<TripCompleteScreen> {
  late Ride _ride = widget.ride;
  int _stars = 5;
  double? _tip = 10;
  bool _rated = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rated = widget.ride.myRating != null;
  }

  RideController get _rc => context.read<RideController>();

  Future<void> _pay(PaymentMethod m) async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      final r = await session.api.pay(_ride.id, m);
      setState(() => _ride = r);
      session.refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate() async {
    setState(() => _busy = true);
    try {
      await context.read<Session>().api.rate(_ride.id, _stars, tip: _ride.paymentMethod == PaymentMethod.wallet ? _tip : null);
      setState(() => _rated = true);
      if (mounted) {
        showToast(context, 'Thanks for rating ${_ride.driver?.shortName ?? 'your driver'}!');
        context.read<Session>().refresh();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _receipt() {
    final r = _ride;
    SharePlus.instance.share(ShareParams(
      subject: 'FreeTongRide receipt ${r.code}',
      text: 'FreeTongRide receipt ${r.code}\n'
          '${tripDate(r.createdAt)}\n'
          'From: ${r.pickup.address}\nTo: ${r.dropoff.address}\n'
          'Distance: ${r.distanceKm.toStringAsFixed(1)} km\n'
          'Driver: ${r.driver?.fullName ?? '-'} (${r.driver?.vehicle ?? ''})\n'
          'Fare: ${le(r.fare)}${(r.discount ?? 0) > 0 ? '\nDiscount: - ${le(r.discount!)}' : ''}${(r.tip ?? 0) > 0 ? '\nTip: ${le(r.tip!)}' : ''}\n'
          'Total: ${le(r.fareDue + (r.tip ?? 0))} (${r.paymentMethod.label})',
    ));
  }

  void _home() {
    if (!widget.fromHistory) _rc.clear();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Live updates while we wait for the driver to confirm cash.
    if (!widget.fromHistory) {
      final live = context.watch<RideController>().ride;
      if (live != null && live.id == _ride.id && live.status != _ride.status) _ride = live;
    }
    final r = _ride;
    final paid = r.paymentStatus == PaymentStatus.paid;
    final cancelled = r.status == RideStatus.cancelled;
    final minutes = r.startedAt != null && r.endedAt != null ? r.endedAt!.difference(r.startedAt!).inMinutes.clamp(1, 600) : r.durationMinutes;

    return PopScope(
      canPop: widget.fromHistory,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              FtrTopBar(
                leading: IconButton(tooltip: 'Back', onPressed: widget.fromHistory ? () => Navigator.pop(context) : _home, icon: const Icon(Icons.arrow_back_rounded, size: 30)),
                hasUnread: false,
              ),
              if (!cancelled) ...[
                FtrHero('hero_trip_complete.png', height: 210),
                Text(paid ? 'Trip completed' : 'You have arrived', textAlign: TextAlign.center, style: FtrText.display.copyWith(fontSize: 34)),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Thank you for riding with '),
                    TextSpan(text: 'FreeTongRide!', style: FtrText.title.copyWith(fontSize: 16.5)),
                  ]),
                  textAlign: TextAlign.center,
                  style: FtrText.body.copyWith(fontSize: 16.5),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Cancelled trip', textAlign: TextAlign.center, style: FtrText.display.copyWith(fontSize: 30)),
                ),
              const SizedBox(height: 16),
              FtrCard(
                child: IntrinsicHeight(
                  child: Row(children: [
                    Expanded(
                      flex: 11,
                      child: FtrRouteSummary(
                        fromLabel: 'From',
                        from: r.pickup.address,
                        fromCaption: r.startedAt == null ? null : clock(r.startedAt!),
                        toLabel: 'To',
                        to: r.dropoff.address,
                        toCaption: r.endedAt == null ? null : clock(r.endedAt!),
                      ),
                    ),
                    const VerticalDivider(width: 24),
                    Expanded(
                      flex: 9,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: FtrColors.blue),
                          const SizedBox(width: 8),
                          Flexible(child: Text(tripDate(r.createdAt).split(' •').first, style: FtrText.small.copyWith(color: FtrColors.body))),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.schedule_rounded, size: 18, color: FtrColors.blue),
                          const SizedBox(width: 8),
                          Flexible(child: Text('$minutes min • ${r.distanceKm.toStringAsFixed(1)} km', style: FtrText.small.copyWith(color: FtrColors.body))),
                        ]),
                        const Divider(height: 20),
                        Text('Total fare', style: FtrText.bodyMuted),
                        Text(le(cancelled ? 0 : r.fareDue + (r.tip ?? 0)), style: FtrText.display.copyWith(color: FtrColors.green, fontSize: 30)),
                      ]),
                    ),
                  ]),
                ),
              ),
              if (!cancelled) ...[
                const SizedBox(height: 12),
                FtrCard(
                  child: Column(children: [
                    Align(alignment: Alignment.centerLeft, child: Text('Fare breakdown', style: FtrText.title.copyWith(fontSize: 17))),
                    const SizedBox(height: 10),
                    _line('${r.serviceName} fare (${r.distanceKm.toStringAsFixed(1)} km)', le(r.fare)),
                    if ((r.discount ?? 0) > 0) _line('Promo discount', '- ${le(r.discount!)}', color: FtrColors.green),
                    if ((r.tip ?? 0) > 0) _line('Tip', le(r.tip!)),
                    const Divider(height: 22),
                    _line(paid ? 'Total paid' : 'Total to pay', le(r.fareDue + (r.tip ?? 0)), bold: true),
                  ]),
                ),
                const SizedBox(height: 12),
                _PaymentCard(ride: r, busy: _busy, onPay: _pay),
                if (paid && r.driver != null) ...[
                  const SizedBox(height: 12),
                  _RateCard(
                    ride: r,
                    stars: _rated ? (r.myRating ?? _stars) : _stars,
                    rated: _rated,
                    onStars: (s) => setState(() => _stars = s),
                  ),
                  if (!_rated && r.paymentMethod == PaymentMethod.wallet) ...[
                    const SizedBox(height: 12),
                    _TipCard(value: _tip, onChanged: (v) => setState(() => _tip = v)),
                  ],
                  if (!_rated) ...[
                    const SizedBox(height: 14),
                    FtrPrimaryButton(label: 'Submit rating', icon: Icons.star_rounded, showArrow: false, loading: _busy, onPressed: _rate),
                  ],
                ],
              ],
              const SizedBox(height: 14),
              FtrPrimaryButton(label: 'Download receipt', icon: Icons.download_rounded, showArrow: false, onPressed: cancelled ? null : _receipt, height: 56),
              const SizedBox(height: 10),
              FtrOutlineButton(
                label: 'Book again',
                icon: Icons.sync_rounded,
                filled: true,
                onPressed: () {
                  if (!widget.fromHistory) _rc.clear();
                  go(context, ChooseRideScreen(pickup: r.pickup, dropoff: r.dropoff), replace: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: bold ? FtrText.title.copyWith(fontSize: 17) : FtrText.body.copyWith(color: FtrColors.muted))),
          Text(value, style: bold ? FtrText.h3.copyWith(fontSize: 18) : FtrText.body.copyWith(color: color ?? FtrColors.ink, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.ride, required this.busy, required this.onPay});
  final Ride ride;
  final bool busy;
  final ValueChanged<PaymentMethod> onPay;

  @override
  Widget build(BuildContext context) {
    final r = ride;
    final paid = r.paymentStatus == PaymentStatus.paid;
    final cash = r.paymentMethod == PaymentMethod.cash;
    return FtrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Payment method', style: FtrText.title.copyWith(fontSize: 17)),
        const SizedBox(height: 10),
        Row(children: [
          FtrIconTile(cash ? Icons.payments_rounded : Icons.account_balance_wallet_rounded, size: 56, color: cash ? FtrColors.green : FtrColors.blue,
              background: cash ? FtrColors.greenSoft : FtrColors.blueSoft),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cash ? 'Cash' : 'Wallet', style: FtrText.title.copyWith(fontSize: 17)),
              Text(cash ? (paid ? 'Paid to your driver' : 'Pay your driver in cash') : 'FreeTongRide Wallet', style: FtrText.bodyMuted),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(le(r.fareDue + (r.tip ?? 0)), style: FtrText.title.copyWith(fontSize: 17)),
            const SizedBox(height: 4),
            paid ? FtrStatusPill.paid() : const FtrStatusPill(label: 'Waiting', color: FtrColors.orange),
          ]),
        ]),
        if (!paid) ...[
          const SizedBox(height: 14),
          if (cash)
            Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text('Waiting for ${r.driver?.shortName ?? 'the driver'} to confirm the cash.', style: FtrText.bodyMuted)),
            ])
          else
            FtrChipButton(label: 'Pay ${le(r.fareDue)} from wallet', primary: true, onPressed: busy ? null : () => onPay(PaymentMethod.wallet)),
          const SizedBox(height: 8),
          if (!cash) Center(child: FtrLink('Pay with cash instead', fontSize: 14.5, onTap: busy ? null : () => onPay(PaymentMethod.cash))),
        ],
      ]),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.ride, required this.stars, required this.rated, required this.onStars});
  final Ride ride;
  final int stars;
  final bool rated;
  final ValueChanged<int> onStars;

  @override
  Widget build(BuildContext context) {
    final d = ride.driver!;
    return FtrCard(
      child: Row(children: [
        FtrAvatar(name: d.fullName, photoUrl: context.read<Session>().client.absolute(d.photoUrl), size: 58),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rated ? 'You rated' : 'Rate your driver', style: FtrText.bodyMuted),
            Text(d.shortName, style: FtrText.h3.copyWith(fontSize: 19)),
            FtrRating(rating: d.rating, count: d.ratingCount, size: 13),
          ]),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: rated ? null : () => onStars(i),
                child: Icon(Icons.star_rounded, size: 25, color: i <= stars ? FtrColors.star : const Color(0xFFDDE2EA)),
              ),
          ],
        ),
      ]),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.value, required this.onChanged});
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, double? v) {
      final selected = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(selected ? null : v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? FtrColors.blue : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: selected ? FtrColors.blue : FtrColors.border, width: 1.3),
            ),
            child: Text(label, style: FtrText.label.copyWith(color: selected ? Colors.white : FtrColors.ink, fontSize: 15)),
          ),
        ),
      );
    }

    return FtrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add a tip (optional)', style: FtrText.title.copyWith(fontSize: 17)),
        Text('Show appreciation for a great trip.', style: FtrText.bodyMuted),
        const SizedBox(height: 12),
        Row(children: [chip('Le 5', 5), chip('Le 10', 10), chip('Le 20', 20), chip('None', null)]),
      ]),
    );
  }
}
