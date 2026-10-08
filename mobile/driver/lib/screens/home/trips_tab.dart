import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

/// Trip history (Canvas 8 style).
class TripsTab extends StatefulWidget {
  const TripsTab({super.key});

  @override
  State<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends State<TripsTab> {
  List<Ride>? _rides;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await context.read<Session>().api.rides();
      if (mounted) setState(() => _rides = p.items);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
          const FtrTopBar(hasUnread: false, leading: SizedBox(width: 48)),
          Text('Your trips', style: FtrText.display.copyWith(fontSize: 32)),
          Text('Every ride you have driven.', style: FtrText.body.copyWith(color: FtrColors.muted)),
          const SizedBox(height: 16),
          if (_rides == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_rides!.isEmpty)
            const FtrEmptyState(icon: Icons.directions_car_rounded, title: 'No trips yet', message: 'Go online to get your first request.')
          else
            for (final r in _rides!) ...[
              FtrCard(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text(tripDate(r.createdAt), style: FtrText.bodyMuted)),
                    switch (r.status) {
                      RideStatus.completed => FtrStatusPill.completed(),
                      RideStatus.cancelled => FtrStatusPill.cancelled(),
                      _ => const FtrStatusPill(label: 'Active', color: FtrColors.blue),
                    },
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: FtrRouteSummary(from: r.pickup.address, to: r.dropoff.address, dense: true)),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(le(r.status == RideStatus.cancelled ? 0 : r.fareDue + (r.tip ?? 0) - (r.commission ?? 0)),
                          style: FtrText.h3.copyWith(color: FtrColors.green)),
                      Text('${r.passenger.fullName.split(' ').first} • ${r.paymentMethod.label}', style: FtrText.small),
                    ]),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],
        ]),
      ),
    );
  }
}
