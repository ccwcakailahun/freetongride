import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../ride/choose_destination_screen.dart';
import '../ride/choose_ride_screen.dart';
import 'common.dart';
import 'shell.dart';

/// Canvas 1 — Home.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<SavedPlace> _places = [];

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final p = await context.read<Session>().api.places();
      if (mounted) setState(() => _places = p);
    } catch (_) {}
  }

  Place _pickup() {
    final pos = here.position;
    if (pos != null) return Place(here.label, pos.latitude, pos.longitude);
    final home = _places.where((p) => p.label == 'Home').firstOrNull;
    return home?.place ?? FreetownPlaces.all[1];
  }

  void _whereTo({bool forOthers = false}) => go(context, ChooseDestinationScreen(pickup: _pickup(), forSomeoneElse: forOthers));

  void _rideTo(Place dest) => go(context, ChooseRideScreen(pickup: _pickup(), dropoff: dest));

  Future<void> _savedPlace(String label) async {
    final existing = _places.where((p) => p.label == label).firstOrNull;
    if (existing != null) return _rideTo(existing.place);
    final place = await go<Place>(context, ChooseDestinationScreen(pickOnly: true, title: 'Add $label address'));
    if (place == null || !mounted) return;
    try {
      await context.read<Session>().api.savePlace(label, place);
      _loadPlaces();
      if (mounted) showToast(context, '$label saved. Tap it any time to book a ride there.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _comingSoon(String what) => showToast(context, '$what is coming soon.', icon: Icons.info_outline_rounded);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: PassengerDrawer(onTab: (i) => HomeShell.switchTab(context, i)),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await here.load(context.read<PlacesService>());
            await _loadPlaces();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
            children: [
              Builder(builder: (ctx) => FtrTopBar(onMenu: () => Scaffold.of(ctx).openDrawer(), onBell: () => _comingSoon('Notifications inbox'))),
              const SizedBox(height: 6),
              GreetingHeader(onLocationTap: () => here.load(context.read<PlacesService>())),
              const SizedBox(height: 18),
              _WhereTo(onTap: _whereTo),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _ServiceAction(icon: Icons.directions_car_filled_rounded, color: FtrColors.blue, title: 'Ride', subtitle: 'Get a ride\nnow', onTap: _whereTo)),
                const SizedBox(width: 10),
                Expanded(child: _ServiceAction(icon: Icons.calendar_month_rounded, color: FtrColors.green, title: 'Schedule', subtitle: 'Plan ahead', onTap: () => _comingSoon('Scheduling rides'))),
                const SizedBox(width: 10),
                Expanded(child: _ServiceAction(icon: Icons.groups_rounded, color: FtrColors.blue, title: 'For Others', subtitle: 'Book for\nfamily or friends', onTap: () => _whereTo(forOthers: true))),
                const SizedBox(width: 10),
                Expanded(child: _ServiceAction(icon: Icons.inventory_2_rounded, color: FtrColors.purple, title: 'Package', subtitle: 'Send items\nacross Freetown', onTap: () => _comingSoon('Package delivery'))),
              ]),
              const SizedBox(height: 18),
              _MapCard(places: _places, onTap: _whereTo),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _PlaceChip(icon: Icons.home_rounded, color: FtrColors.blue, label: 'Home', place: _places.where((p) => p.label == 'Home').firstOrNull, onTap: () => _savedPlace('Home'))),
                const SizedBox(width: 10),
                Expanded(child: _PlaceChip(icon: Icons.work_rounded, color: FtrColors.blue, label: 'Work', place: _places.where((p) => p.label == 'Work').firstOrNull, onTap: () => _savedPlace('Work'))),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlaceChip(
                    icon: Icons.star_rounded,
                    color: FtrColors.orange,
                    label: 'Favorites',
                    caption: 'See all',
                    onTap: () => go(context, ChooseDestinationScreen(pickup: _pickup())),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              ClipRRect(borderRadius: BorderRadius.circular(22), child: ftrImage('promo_safe_rides.png', fit: BoxFit.cover)),
              const SizedBox(height: 22),
              FtrSectionHeader('Popular destinations', action: 'See all', onAction: () => go(context, ChooseDestinationScreen(pickup: _pickup()))),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (place, image) in FreetownPlaces.popular) ...[
                    Expanded(child: _Destination(place: place, image: image, from: here.position, onTap: () => _rideTo(place))),
                    if (place != FreetownPlaces.popular.last.$1) const SizedBox(width: 10),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhereTo extends StatelessWidget {
  const _WhereTo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FtrCard(
      radius: 40,
      padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
      onTap: onTap,
      child: Row(children: [
        const FtrIconTile(Icons.search_rounded, size: 60, circle: true, iconSize: 32),
        const SizedBox(width: 16),
        Expanded(child: Text('Where to?', style: FtrText.h2.copyWith(fontSize: 22, fontWeight: FontWeight.w600))),
        Container(width: 1.2, height: 36, color: FtrColors.border),
        const SizedBox(width: 18),
        Transform.rotate(angle: 0.6, child: const Icon(Icons.navigation_outlined, color: FtrColors.blue, size: 30)),
      ]),
    );
  }
}

class _ServiceAction extends StatelessWidget {
  const _ServiceAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1.05,
          child: Container(
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(22)),
            child: Icon(icon, color: color, size: 40),
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: FtrText.title.copyWith(fontSize: 16)),
        const SizedBox(height: 2),
        Text(subtitle, textAlign: TextAlign.center, style: FtrText.small.copyWith(fontSize: 12.5, height: 1.25)),
      ]),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.places, required this.onTap});
  final List<SavedPlace> places;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: here,
      builder: (context, _) {
        final me = here.position ?? const LatLng(8.4400, -13.2700);
        final work = places.where((p) => p.label == 'Work').firstOrNull;
        final dest = work != null ? LatLng(work.lat, work.lng) : const LatLng(8.4844, -13.2344);
        return Container(
          height: 210,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: ftrSoftShadow),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            FtrMap(
              key: ValueKey(me),
              interactive: false,
              fitPoints: [me, dest],
              padding: const EdgeInsets.fromLTRB(40, 40, 170, 50),
              markers: [
                if (here.position != null) youAreHere(me),
                pickupPin(here.position == null ? const LatLng(8.4207, -13.2930) : me, label: here.position == null ? 'Lumley Beach' : 'You are here'),
                dropoffPin(dest, label: work != null ? 'Work' : 'Freetown Central'),
              ],
            ),
            Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: onTap))),
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  tooltip: 'Find my location',
                  onPressed: () => here.load(context.read<PlacesService>()),
                  icon: const Icon(Icons.my_location_rounded, color: FtrColors.ink),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.icon, required this.color, required this.label, required this.onTap, this.place, this.caption});
  final IconData icon;
  final Color color;
  final String label;
  final SavedPlace? place;
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FtrCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(7, 9, 2, 9),
      onTap: onTap,
      child: Row(children: [
        FtrIconTile(icon, color: color, background: color.withValues(alpha: 0.1), size: 34, iconSize: 21),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, style: FtrText.title.copyWith(fontSize: 13.5)),
            Text(caption ?? (place == null ? 'Add address' : place!.address), maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small.copyWith(fontSize: 11)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: FtrColors.muted, size: 16),
      ]),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({required this.place, required this.image, required this.onTap, this.from});
  final Place place;
  final String image;
  final LatLng? from;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = from ?? const LatLng(8.4207, -13.2930);
    final minutes = (const Distance().as(LengthUnit.Kilometer, f, LatLng(place.lat, place.lng)) * 1.3 / 22 * 60).ceil().clamp(3, 90);
    return FtrCard(
      padding: EdgeInsets.zero,
      radius: 16,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: AspectRatio(aspectRatio: 1.55, child: ftrImage(image, fit: BoxFit.cover)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 13, color: FtrColors.ink),
              const SizedBox(width: 2),
              Flexible(child: Text('$minutes min away', maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small.copyWith(fontSize: 11.5))),
            ]),
          ]),
        ),
      ]),
    );
  }
}
