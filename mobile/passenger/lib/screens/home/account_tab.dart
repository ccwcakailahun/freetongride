import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../main.dart';
import '../onboarding/complete_profile_screen.dart';
import '../onboarding/sign_in_screen.dart';
import '../onboarding/notifications_permission_screen.dart';
import 'common.dart';
import 'shell.dart';

/// Canvas 10 — Account.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  void _soon(BuildContext context, String what) => showToast(context, '$what is coming soon.', icon: Icons.info_outline_rounded);

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmSheet(context, title: 'Sign out?', message: 'You will need your phone number and password to sign in again.', confirmLabel: 'Sign Out', destructive: true);
    if (!ok || !context.mounted) return;
    await context.read<Session>().signOut();
    if (context.mounted) go(context, const SignInScreen(), clear: true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final u = session.user!;
    void edit() => go(context, const CompleteProfileScreen(editing: true));
    Widget detail(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(i, color: FtrColors.blue, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.body.copyWith(fontSize: 16, color: FtrColors.ink))),
          ]),
        );

    return Scaffold(
      drawer: PassengerDrawer(onTab: (i) => HomeShell.switchTab(context, i)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
          children: [
            Builder(builder: (ctx) => FtrTopBar(onMenu: () => Scaffold.of(ctx).openDrawer())),
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: edit,
                child: FtrAvatar(name: u.fullName, photoUrl: session.client.absolute(u.photoUrl), size: 140, badge: const FtrCameraBadge(color: FtrColors.green, size: 44)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(firstName(u.fullName), style: FtrText.h1.copyWith(fontSize: 28)),
                  const SizedBox(height: 8),
                  detail(Icons.call_rounded, prettyPhone(u.phone)),
                  if (u.email != null) detail(Icons.mail_rounded, u.email!),
                  detail(Icons.location_on_rounded, u.homeArea ?? 'Freetown'),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            FtrOutlineButton(label: 'Edit Profile', icon: Icons.edit_rounded, filled: true, onPressed: edit),
            const SizedBox(height: 16),
            ..._menu(context, [
              (Icons.person_rounded, FtrColors.blue, 'Personal Info', 'Name, phone number, email', edit),
              (Icons.location_on_rounded, FtrColors.green, 'Saved Places', 'Home, Work and other locations', edit),
              (Icons.verified_user_rounded, FtrColors.green, 'Safety', 'Your safety tools and preferences', () => _soon(context, 'Safety centre')),
              (Icons.credit_card_rounded, FtrColors.blue, 'Payment Methods', 'Cards, mobile money and more', () => HomeShell.switchTab(context, 2)),
              (Icons.headset_mic_rounded, FtrColors.blue, 'Help & Support', 'Get help, contact us', () => _soon(context, 'In-app support')),
              (Icons.notifications_rounded, FtrColors.orange, 'Notifications', 'Ride updates, promotions and more', () => go(context, const NotificationsPermissionScreen())),
              (Icons.settings_rounded, FtrColors.body, 'Settings', 'App preferences and privacy', () => _soon(context, 'Settings')),
              (Icons.groups_rounded, FtrColors.blue, 'Refer a Friend', 'Share FreeTongRide and earn rewards',
                  () => SharePlus.instance.share(ShareParams(text: 'Ride safely across Freetown with FreeTongRide. Moving Freetown Together!'))),
              (Icons.logout_rounded, FtrColors.red, 'Sign Out', 'Log out from your account', () => _signOut(context)),
            ]),
            const SizedBox(height: 4),
            const FtrSafetyBanner(compact: true, title: 'Your safety comes first', message: 'All drivers are verified and trained.', onTap: null),
          ],
        ),
      ),
    );
  }

  List<Widget> _menu(BuildContext context, List<(IconData, Color, String, String, VoidCallback)> items) => [
        for (final (icon, color, title, sub, onTap) in items) ...[
          FtrFeatureTile(icon: icon, color: color, title: title, subtitle: sub, onTap: onTap, chevron: true, tinted: false, iconSize: 54),
          const SizedBox(height: 10),
        ],
      ];
}
