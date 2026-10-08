import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../state/driver_controller.dart';
import '../auth/sign_in_screen.dart';
import '../onboarding/documents_screen.dart';
import '../onboarding/vehicle_screen.dart';

/// Driver version of Canvas 10.
class DriverAccountTab extends StatelessWidget {
  const DriverAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final dc = context.watch<DriverController>();
    final u = session.user!;
    final p = dc.profile;

    Future<void> signOut() async {
      final ok = await confirmSheet(context, title: 'Sign out?', message: 'You will go offline and stop receiving requests.', confirmLabel: 'Sign Out', destructive: true);
      if (!ok || !context.mounted) return;
      if (dc.online) await dc.setOnline(false).catchError((_) {});
      await session.signOut();
      if (context.mounted) go(context, const SignInScreen(), clear: true);
    }

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
        const FtrTopBar(hasUnread: false, leading: SizedBox(width: 48)),
        Row(children: [
          FtrAvatar(name: u.fullName, photoUrl: session.client.absolute(u.photoUrl), size: 110, online: dc.online),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.fullName, style: FtrText.h2),
              const SizedBox(height: 4),
              FtrRating(rating: u.rating, count: u.ratingCount),
              const SizedBox(height: 4),
              Text(prettyPhone(u.phone), style: FtrText.body),
              if (p != null) Text('${p.completedTrips} trips completed', style: FtrText.small),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        if (p != null)
          FtrCard(
            child: Row(children: [
              FtrIconTile(serviceIcon(p.serviceName ?? 'car'), size: 56, color: FtrColors.green, background: FtrColors.greenSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p.vehicleMake ?? ''} ${p.vehicleModel ?? ''}', style: FtrText.title.copyWith(fontSize: 17)),
                  Text('${p.vehicleColor ?? ''} • ${p.plateNumber ?? ''} • ${p.serviceName ?? ''}', style: FtrText.bodyMuted),
                ]),
              ),
              const FtrStatusPill(label: 'Verified', color: FtrColors.green, icon: Icons.verified_rounded),
            ]),
          ),
        const SizedBox(height: 16),
        for (final (icon, color, title, sub, onTap) in <(IconData, Color, String, String, VoidCallback)>[
          (Icons.directions_car_rounded, FtrColors.green, 'Vehicle', 'Update your vehicle details', () => go(context, const VehicleScreen(editing: true))),
          (Icons.folder_rounded, FtrColors.blue, 'Documents', 'Licence, ID and vehicle photos', () => go(context, const DocumentsScreen(viewOnly: true))),
          (Icons.headset_mic_rounded, FtrColors.blue, 'Help & Support', 'Get help, contact us', () => showToast(context, 'Driver support chat is coming soon.', icon: Icons.info_outline_rounded)),
          (Icons.logout_rounded, FtrColors.red, 'Sign Out', 'Log out from your account', signOut),
        ]) ...[
          FtrFeatureTile(icon: icon, color: color, title: title, subtitle: sub, onTap: onTap, chevron: true, tinted: false, iconSize: 52),
          const SizedBox(height: 10),
        ],
        const FtrSafetyBanner(compact: true, title: 'Drive safe, earn more', message: 'Riders rate safe, polite driving. Higher ratings get more requests.'),
      ]),
    );
  }
}
