import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';

import 'account_tab.dart';
import 'driver_home_tab.dart';
import 'earnings_tab.dart';
import 'trips_tab.dart';

/// Home · Trips · Earnings · Account, with green as the active colour.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _items = [
    FtrNavItem('Drive', Icons.navigation_outlined, Icons.navigation_rounded),
    FtrNavItem('Trips', Icons.schedule_rounded, Icons.watch_later_rounded),
    FtrNavItem('Earnings', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
    FtrNavItem('Account', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    const pages = [DriverHomeTab(), TripsTab(), EarningsTab(), DriverAccountTab()];
    return Scaffold(
      body: IndexedStack(index: _index, children: [for (var i = 0; i < pages.length; i++) _visited.contains(i) ? pages[i] : const SizedBox()]),
      bottomNavigationBar: FtrBottomNav(
        items: _items,
        index: _index,
        accent: FtrColors.green,
        onChanged: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
      ),
    );
  }
}
