import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/driver_controller.dart';
import '../auth/sign_in_screen.dart';
import '../home/driver_shell.dart';
import 'documents_screen.dart';
import 'vehicle_screen.dart';

/// Step 4: waiting for the admin team. Updates live when the review comes back.
class ReviewStatusScreen extends StatelessWidget {
  const ReviewStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dc = context.watch<DriverController>();
    final p = dc.profile!;
    final rejected = p.status == DriverStatus.rejected;
    final suspended = p.status == DriverStatus.suspended;
    if (p.status == DriverStatus.approved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => go(context, const DriverShell(), clear: true));
    }
    final (icon, color, title, message) = switch (p.status) {
      DriverStatus.rejected => (Icons.error_outline_rounded, FtrColors.red, 'Changes needed', p.rejectReason ?? 'Some details need fixing. Update them and submit again.'),
      DriverStatus.suspended => (Icons.block_rounded, FtrColors.red, 'Account suspended', 'Contact FreeTongRide support to find out more.'),
      DriverStatus.approved => (Icons.verified_rounded, FtrColors.green, 'You are approved!', 'Welcome to FreeTongRide.'),
      _ => (Icons.hourglass_top_rounded, FtrColors.orange, 'Under review', 'We are checking your documents and vehicle. You will get a notification as soon as you are approved.'),
    };
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: dc.reloadProfile,
            child: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), children: [
              const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
              const SizedBox(height: 18),
              const StepBar(step: 4),
              const SizedBox(height: 36),
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 76, color: color),
                ),
              ),
              const SizedBox(height: 22),
              Text(title, textAlign: TextAlign.center, style: FtrText.display.copyWith(fontSize: 32)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5, color: rejected ? FtrColors.red : FtrColors.muted)),
              const SizedBox(height: 26),
              FtrCard(
                child: Column(children: [
                  _Row(icon: Icons.directions_car_rounded, label: 'Vehicle', value: '${p.serviceName ?? '-'} • ${p.vehicleMake ?? ''} ${p.vehicleModel ?? ''} • ${p.plateNumber ?? ''}'),
                  const Divider(height: 22),
                  _Row(icon: Icons.folder_rounded, label: 'Documents', value: '${p.documents.length} uploaded'),
                ]),
              ),
              const SizedBox(height: 20),
              if (rejected) ...[
                DriverButton(label: 'Fix documents', onPressed: () => go(context, const DocumentsScreen())),
                const SizedBox(height: 10),
                FtrOutlineButton(label: 'Edit vehicle', onPressed: () => go(context, const VehicleScreen(editing: true))),
              ] else if (!suspended)
                FtrOutlineButton(label: 'Check again', icon: Icons.refresh_rounded, onPressed: dc.reloadProfile),
              const SizedBox(height: 10),
              Center(
                child: FtrLink('Sign out', onTap: () async {
                  await context.read<Session>().signOut();
                  if (context.mounted) go(context, const SignInScreen(), clear: true);
                }),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        FtrIconTile(icon, size: 46, color: FtrColors.green, background: FtrColors.greenSoft),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: FtrText.small),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: FtrText.title),
          ]),
        ),
      ]);
}
