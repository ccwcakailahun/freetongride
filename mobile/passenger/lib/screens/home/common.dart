import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

/// Current temperature for Freetown from Open-Meteo (free, no key). Cached for 20 minutes.
class Weather {
  static ({double temp, int code})? _cache;
  static DateTime? _at;

  static Future<({double temp, int code})?> now(double lat, double lng) async {
    if (_cache != null && DateTime.now().difference(_at!) < const Duration(minutes: 20)) return _cache;
    try {
      final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code');
      final j = jsonDecode((await http.get(uri).timeout(const Duration(seconds: 6))).body);
      _cache = (temp: (j['current']['temperature_2m'] as num).toDouble(), code: j['current']['weather_code'] as int);
      _at = DateTime.now();
      return _cache;
    } catch (_) {
      return _cache;
    }
  }

  static IconData icon(int code) => switch (code) {
        0 => Icons.wb_sunny_rounded,
        1 || 2 => Icons.wb_cloudy_outlined,
        3 || 45 || 48 => Icons.cloud_rounded,
        >= 95 => Icons.thunderstorm_rounded,
        >= 51 => Icons.water_drop_rounded,
        _ => Icons.wb_sunny_rounded,
      };
}

/// Where the passenger is now, as a name ("Lumley Beach, Freetown"). Shared by the tabs.
class HereNotifier extends ChangeNotifier {
  LatLng? position;
  String label = 'Freetown';
  bool _loading = false;

  Future<void> load(PlacesService places) async {
    if (_loading) return;
    _loading = true;
    final p = await LocationService.current();
    if (p != null) {
      position = LatLng(p.latitude, p.longitude);
      label = await places.nameFor(p.latitude, p.longitude);
      notifyListeners();
    }
    _loading = false;
  }
}

final here = HereNotifier();

/// Avatar, "Good morning," name, location; weather on the right (Home and Wallet headers).
class GreetingHeader extends StatefulWidget {
  const GreetingHeader({super.key, this.onLocationTap});
  final VoidCallback? onLocationTap;

  @override
  State<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<GreetingHeader> {
  ({double temp, int code})? _weather;

  @override
  void initState() {
    super.initState();
    here.load(context.read<PlacesService>());
    final p = here.position ?? FreetownPlaces.centre;
    Weather.now(p.latitude, p.longitude).then((w) {
      if (mounted) setState(() => _weather = w);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user!;
    return ListenableBuilder(
      listenable: here,
      builder: (context, _) => Row(
        children: [
          FtrAvatar(name: user.fullName, photoUrl: session.client.absolute(user.photoUrl), size: 84),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting(), style: FtrText.body.copyWith(fontSize: 16)),
              Text(firstName(user.fullName), style: FtrText.h1.copyWith(fontSize: 27), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              InkWell(
                onTap: widget.onLocationTap,
                borderRadius: BorderRadius.circular(8),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded, color: FtrColors.green, size: 20),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(here.label == 'Freetown' ? (user.homeArea ?? 'Freetown') : here.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.body.copyWith(fontSize: 15.5, color: FtrColors.ink)),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: FtrColors.blue),
                ]),
              ),
            ]),
          ),
          if (_weather != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Icon(Weather.icon(_weather!.code), color: FtrColors.orange, size: 30),
                const SizedBox(width: 6),
                Text('${_weather!.temp.round()}°C', style: FtrText.h3.copyWith(fontSize: 20)),
              ]),
              Text('Freetown', style: FtrText.small),
            ]),
        ],
      ),
    );
  }
}

/// Menu drawer opened from the hamburger on the main tabs.
class PassengerDrawer extends StatelessWidget {
  const PassengerDrawer({super.key, required this.onTab});
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final u = session.user!;
    Widget item(IconData i, String t, VoidCallback onTap) => ListTile(
          leading: Icon(i, color: FtrColors.blue),
          title: Text(t, style: FtrText.title),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        );
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Row(children: [
              FtrAvatar(name: u.fullName, photoUrl: session.client.absolute(u.photoUrl), size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.fullName, style: FtrText.h3),
                  FtrRating(rating: u.rating, size: 13),
                ]),
              ),
            ]),
          ),
          const Divider(),
          item(Icons.home_rounded, 'Home', () => onTab(0)),
          item(Icons.watch_later_rounded, 'Your trips', () => onTab(1)),
          item(Icons.account_balance_wallet_rounded, 'Wallet', () => onTab(2)),
          item(Icons.person_rounded, 'Account', () => onTab(3)),
          const Divider(),
          Padding(padding: const EdgeInsets.all(20), child: FtrBrandHeader(size: FtrBrandSize.compact)),
        ]),
      ),
    );
  }
}
