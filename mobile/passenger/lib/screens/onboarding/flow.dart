import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../home/shell.dart';
import '../ride/trip_screen.dart';
import '../ride/finding_driver_screen.dart';
import '../../state/ride_controller.dart';
import 'complete_profile_screen.dart';
import 'location_permission_screen.dart';
import 'notifications_permission_screen.dart';

/// After sign-in or verification: ask for location, then notifications, then profile, then home.
/// Each step is skipped when already done. An unfinished ride is resumed first.
Future<void> continueAfterSignIn(BuildContext context) async {
  final session = context.read<Session>();
  final rides = context.read<RideController>();

  if (!await LocationService.hasPermission() && context.mounted) {
    await go(context, const LocationPermissionScreen());
  }
  if (!context.mounted) return;
  if (!(await Permission.notification.status).isGranted && !(await Permission.notification.isPermanentlyDenied) && context.mounted) {
    await go(context, const NotificationsPermissionScreen());
  }
  if (!context.mounted) return;
  if (!(session.user?.profileComplete ?? true)) {
    await go(context, const CompleteProfileScreen());
  }
  if (!context.mounted) return;

  final ride = await rides.loadCurrent();
  if (!context.mounted) return;
  await go(context, const HomeShell(), clear: true);
  if (ride != null && context.mounted) {
    final nav = navigatorKey.currentContext ?? context;
    if (!nav.mounted) return;
    go(nav, ride.status == RideStatus.searching ? const FindingDriverScreen() : const TripScreen());
  }
}
