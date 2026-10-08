import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/ride_controller.dart';
import '../ride/finding_driver_screen.dart';
import '../ride/trip_screen.dart';
import 'account_tab.dart';
import 'activity_tab.dart';
import 'home_tab.dart';
import 'wallet_tab.dart';

/// Bottom-nav shell: Home · Activity · Wallet · Account.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static void switchTab(BuildContext context, int index) => context.findAncestorStateOfType<_HomeShellState>()?._go(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};

  void _go(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  static const _items = [
    FtrNavItem('Home', Icons.home_outlined, Icons.home_rounded),
    FtrNavItem('Activity', Icons.schedule_rounded, Icons.watch_later_rounded),
    FtrNavItem('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
    FtrNavItem('Account', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [const HomeTab(), const ActivityTab(), const WalletTab(), const AccountTab()];
    return Scaffold(
      extendBody: true,
      body: Stack(children: [
        IndexedStack(index: _index, children: [for (var i = 0; i < pages.length; i++) _visited.contains(i) ? pages[i] : const SizedBox()]),
        const Positioned(left: 16, right: 16, bottom: 104, child: _ActiveRideBanner()),
      ]),
      bottomNavigationBar: FtrBottomNav(items: _items, index: _index, onChanged: _go),
    );
  }
}

/// Floating "Your ride" pill shown on every tab while a ride is active.
class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner();

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideController>();
    final r = rides.ride;
    if (r == null || !r.status.isActive) return const SizedBox.shrink();
    final text = switch (r.status) {
      RideStatus.searching => 'Finding a driver for you…',
      RideStatus.driverAssigned => '${r.driver?.shortName ?? 'Your driver'} is on the way',
      RideStatus.driverArrived => '${r.driver?.shortName ?? 'Your driver'} has arrived',
      RideStatus.inProgress => 'On your trip to ${r.dropoff.address}',
      _ => 'Finish paying for your trip',
    };
    return Material(
      color: FtrColors.navy,
      borderRadius: BorderRadius.circular(20),
      elevation: 8,
      shadowColor: FtrColors.navy.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => go(context, r.status == RideStatus.searching ? const FindingDriverScreen() : const TripScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(children: [
            const Icon(Icons.directions_car_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: FtrText.title.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('View', style: FtrText.title.copyWith(color: FtrColors.greenBright)),
            const Icon(Icons.chevron_right_rounded, color: FtrColors.greenBright),
          ]),
        ),
      ),
    );
  }
}
