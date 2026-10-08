import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/driver_controller.dart';
import '../home/driver_shell.dart';
import '../onboarding/vehicle_screen.dart';
import '../onboarding/review_status_screen.dart';
import 'sign_in_screen.dart';

/// Sends the driver to the right place: onboarding, waiting for review, or the main app.
Future<void> routeDriver(BuildContext context) async {
  final dc = context.read<DriverController>();
  try {
    await dc.load();
  } catch (e) {
    if (context.mounted) showError(context, e);
    return;
  }
  if (!context.mounted) return;
  final p = dc.profile!;
  if (p.status == DriverStatus.approved) {
    go(context, const DriverShell(), clear: true);
  } else if (!p.hasVehicle || (p.status == DriverStatus.pendingDocuments && p.missingDocuments.isNotEmpty)) {
    go(context, const VehicleScreen(), clear: true);
  } else {
    go(context, const ReviewStatusScreen(), clear: true);
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final session = context.read<Session>();
    await Future.wait([session.restore(), Future.delayed(const Duration(milliseconds: 1400))]);
    if (!mounted) return;
    if (session.signedIn) {
      await routeDriver(context);
    } else {
      go(context, const SignInScreen(), clear: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7F9),
        body: Stack(children: [
          Align(alignment: Alignment.bottomCenter, child: ftrImage('splash_wave.png', width: double.infinity, fit: BoxFit.fitWidth)),
          Align(
            alignment: const Alignment(0, -0.2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: ftrImage('logo_full.png', fit: BoxFit.contain)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(gradient: DriverStyle.gradient, borderRadius: BorderRadius.circular(20)),
                child: Text('DRIVER', style: FtrText.title.copyWith(color: Colors.white, letterSpacing: 4)),
              ),
            ]),
          ),
        ]),
      );
}
