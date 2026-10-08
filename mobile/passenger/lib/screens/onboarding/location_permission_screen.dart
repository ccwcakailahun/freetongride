import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:geolocator/geolocator.dart';

/// Canvas 17 — Enable location.
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    final ok = await LocationService.request();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context);
    } else if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) showError(context, ApiException('Turn on Location in your phone settings, then try again.'));
      await Geolocator.openLocationSettings();
    } else if (mounted) {
      showError(context, ApiException('Location is off for FreeTongRide. You can still type your pickup address.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: FtrFitScreen(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 18),
              const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
              const FtrHero('hero_location.png', height: 330),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Enable '),
                      TextSpan(text: 'location', style: FtrText.display.copyWith(color: FtrColors.blue)),
                    ]),
                    textAlign: TextAlign.center,
                    style: FtrText.display.copyWith(fontSize: 38),
                  ),
                  const SizedBox(height: 10),
                  Text('We use your location to find nearby drivers, estimate fares, and guide pickups.',
                      textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5, color: FtrColors.muted)),
                  const SizedBox(height: 20),
                  FtrCard(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: const [
                      FtrFeatureTile(
                        icon: Icons.bolt_rounded,
                        color: FtrColors.green,
                        title: 'Faster pickups',
                        subtitle: 'Connect with nearby drivers in minutes.',
                        tinted: false,
                      ),
                      SizedBox(height: 8),
                      FtrFeatureTile(
                        icon: Icons.schedule_rounded,
                        color: FtrColors.blue,
                        title: 'More accurate ETAs',
                        subtitle: 'Get reliable arrival times based on your location.',
                      ),
                      SizedBox(height: 8),
                      FtrFeatureTile(
                        icon: Icons.shield_rounded,
                        color: FtrColors.purple,
                        title: 'Safer ride tracking',
                        subtitle: 'Let friends and family follow your trip in real time.',
                      ),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  FtrPrimaryButton(label: 'Enable Location', loading: _busy, onPressed: _enable),
                  const SizedBox(height: 14),
                  FtrOutlineButton(label: 'Not now', onPressed: () => Navigator.pop(context)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
