import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:permission_handler/permission_handler.dart';

/// Canvas 18 — Stay updated.
class NotificationsPermissionScreen extends StatefulWidget {
  const NotificationsPermissionScreen({super.key});

  @override
  State<NotificationsPermissionScreen> createState() => _NotificationsPermissionScreenState();
}

class _NotificationsPermissionScreenState extends State<NotificationsPermissionScreen> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    await Permission.notification.request();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: FtrFitScreen(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            children: [
              const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
              const SizedBox(height: 18),
              SizedBox(height: 230, child: ftrImage('illus_notifications.png', fit: BoxFit.contain)),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Stay '),
                  TextSpan(text: 'updated', style: FtrText.display.copyWith(color: FtrColors.blue)),
                ]),
                textAlign: TextAlign.center,
                style: FtrText.display.copyWith(fontSize: 40),
              ),
              const SizedBox(height: 10),
              Text('Allow notifications so you never miss driver arrivals, trip updates, promos, and receipts.',
                  textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5, color: FtrColors.muted)),
              const SizedBox(height: 22),
              const FtrFeatureTile(
                  icon: Icons.directions_car_rounded, color: FtrColors.green, title: 'Driver arriving', subtitle: 'Get notified when your driver is on the way.', chevron: true),
              const SizedBox(height: 10),
              const FtrFeatureTile(icon: Icons.location_on_rounded, color: FtrColors.blue, title: 'Trip status', subtitle: 'Real-time updates from pickup to drop-off.', chevron: true),
              const SizedBox(height: 10),
              const FtrFeatureTile(
                  icon: Icons.event_rounded, color: FtrColors.purple, title: 'Scheduled ride reminders', subtitle: 'Timely reminders for your upcoming rides.', chevron: true),
              const SizedBox(height: 10),
              const FtrFeatureTile(
                  icon: Icons.card_giftcard_rounded, color: FtrColors.orange, title: 'Promotions & vouchers', subtitle: 'Be the first to know about special offers and discounts.', chevron: true),
              const SizedBox(height: 22),
              FtrPrimaryButton(label: 'Allow Notifications', loading: _busy, onPressed: _allow),
              const SizedBox(height: 14),
              FtrOutlineButton(label: 'Skip for now', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
