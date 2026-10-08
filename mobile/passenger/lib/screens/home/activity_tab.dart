import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../ride/choose_ride_screen.dart';
import '../ride/trip_complete_screen.dart';
import '../ride/trip_screen.dart';
import '../ride/finding_driver_screen.dart';
import '../../state/ride_controller.dart';
import 'common.dart';
import 'shell.dart';

/// Canvas 8 — Activity.
class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  String _filter = 'all';
  List<Ride>? _rides;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await context.read<Session>().api.rides(filter: _filter);
      if (mounted) setState(() => _rides = page.items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _setFilter(String f) {
    setState(() {
      _filter = f;
      _rides = null;
    });
    _load();
  }

  void _open(Ride r) {
    final rides = context.read<RideController>();
    if (r.status.isActive) {
      rides.start(r);
      go(context, r.status == RideStatus.searching ? const FindingDriverScreen() : const TripScreen());
    } else {
      go(context, TripCompleteScreen(ride: r, fromHistory: true));
    }
  }

  void _again(Ride r) => go(context, ChooseRideScreen(pickup: r.pickup, dropoff: r.dropoff));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: PassengerDrawer(onTab: (i) => HomeShell.switchTab(context, i)),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
            children: [
              Builder(builder: (ctx) => FtrTopBar(onMenu: () => Scaffold.of(ctx).openDrawer())),
              const SizedBox(height: 6),
              Text('Activity', style: FtrText.display.copyWith(fontSize: 34)),
              const SizedBox(height: 4),
              Text('Your rides, all in one place.', style: FtrText.body.copyWith(fontSize: 17, color: FtrColors.muted)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _FilterChip(label: 'All', icon: Icons.format_list_bulleted_rounded, selected: _filter == 'all', onTap: () => _setFilter('all'))),
                const SizedBox(width: 10),
                Expanded(child: _FilterChip(label: 'Upcoming', icon: Icons.calendar_month_outlined, selected: _filter == 'upcoming', onTap: () => _setFilter('upcoming'))),
                const SizedBox(width: 10),
                Expanded(child: _FilterChip(label: 'Completed', icon: Icons.check_circle_outline_rounded, selected: _filter == 'completed', onTap: () => _setFilter('completed'))),
              ]),
              const SizedBox(height: 22),
              FtrSectionHeader('Recent trips', action: 'See all', onAction: () => _setFilter('all')),
              const SizedBox(height: 12),
              if (_error != null)
                FtrEmptyState(icon: Icons.wifi_off_rounded, title: 'Could not load your trips', message: '$_error', action: FtrChipButton(label: 'Try again', onPressed: _load))
              else if (_rides == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_rides!.isEmpty)
                FtrEmptyState(
                  icon: Icons.directions_car_rounded,
                  title: _filter == 'upcoming' ? 'No upcoming rides' : 'No trips yet',
                  message: 'Your rides will show here once you book one.',
                )
              else
                for (final r in _rides!) ...[_TripCard(ride: r, onOpen: () => _open(r), onAgain: () => _again(r)), const SizedBox(height: 14)],
              const SizedBox(height: 6),
              _PlanRideCard(onTap: () => HomeShell.switchTab(context, 0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: selected ? FtrColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: selected ? ftrButtonShadow : ftrSoftShadow,
        border: selected ? null : Border.all(color: FtrColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: selected ? Colors.white : FtrColors.ink),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: FtrText.label.copyWith(fontSize: 15, color: selected ? Colors.white : FtrColors.ink))),
          ]),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.ride, required this.onOpen, required this.onAgain});
  final Ride ride;
  final VoidCallback onOpen;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final r = ride;
    final cancelled = r.status == RideStatus.cancelled;
    final pill = switch (r.status) {
      RideStatus.completed => FtrStatusPill.completed(),
      RideStatus.cancelled => FtrStatusPill.cancelled(),
      _ => const FtrStatusPill(label: 'In progress', color: FtrColors.blue, icon: Icons.timelapse_rounded),
    };
    final minutes = r.startedAt != null && r.endedAt != null ? r.endedAt!.difference(r.startedAt!).inMinutes : r.durationMinutes;
    return FtrCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(tripDate(r.createdAt), style: FtrText.bodyMuted.copyWith(fontSize: 14.5))),
          pill,
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: FtrRouteSummary(from: r.pickup.address, to: r.dropoff.address, dense: true)),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Color(0xFFF1F4F9), shape: BoxShape.circle),
            child: const Icon(Icons.directions_car_rounded, color: FtrColors.body, size: 24),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(le(cancelled ? 0 : r.fareDue + (r.tip ?? 0)), style: FtrText.h3.copyWith(fontSize: 19)),
            Text(cancelled ? r.serviceName : '${r.serviceName} • $minutes min', style: FtrText.small),
          ]),
        ]),
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: FtrChipButton(label: cancelled ? 'View details' : (r.status.isActive ? 'Open trip' : 'View receipt'), icon: Icons.receipt_long_outlined, onPressed: onOpen)),
          const SizedBox(width: 12),
          Expanded(child: FtrChipButton(label: 'Book again', icon: Icons.replay_rounded, primary: true, onPressed: onAgain)),
        ]),
      ]),
    );
  }
}

class _PlanRideCard extends StatelessWidget {
  const _PlanRideCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: FtrColors.blueSoft.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
      child: Row(children: [
        SizedBox(width: 130, child: ftrImage('illus_plan_ride.png', fit: BoxFit.contain)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('More trips ahead?', style: FtrText.h3.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text('Book your next ride and keep Freetown moving.', style: FtrText.bodyMuted),
            const SizedBox(height: 10),
            FtrChipButton(label: 'Plan a ride', icon: Icons.calendar_month_outlined, onPressed: onTap, height: 46),
          ]),
        ),
      ]),
    );
  }
}
