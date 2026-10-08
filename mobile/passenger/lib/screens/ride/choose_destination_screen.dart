import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../home/common.dart';
import 'choose_ride_screen.dart';

/// Pickup + "Where to?" search. With [pickOnly] it returns the chosen place instead of booking.
class ChooseDestinationScreen extends StatefulWidget {
  const ChooseDestinationScreen({super.key, this.pickup, this.pickOnly = false, this.title, this.forSomeoneElse = false});
  final Place? pickup;
  final bool pickOnly;
  final String? title;
  final bool forSomeoneElse;

  @override
  State<ChooseDestinationScreen> createState() => _ChooseDestinationScreenState();
}

class _ChooseDestinationScreenState extends State<ChooseDestinationScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  late Place? _pickup = widget.pickup;
  bool _editingPickup = false;
  List<Place> _results = FreetownPlaces.all.take(8).toList();
  List<SavedPlace> _saved = [];
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (!widget.pickOnly) {
      context.read<Session>().api.places().then((p) {
        if (mounted) setState(() => _saved = p);
      }).catchError((_) {});
    }
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      final r = await context.read<PlacesService>().search(q);
      if (mounted) {
        setState(() {
          _results = r;
          _searching = false;
        });
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    if (!await LocationService.hasPermission()) await LocationService.request();
    if (!mounted) return;
    await here.load(context.read<PlacesService>());
    final p = here.position;
    if (p == null) {
      if (mounted) showError(context, ApiException('We could not find your location. Type the address instead.'));
      return;
    }
    _choose(Place(here.label, p.latitude, p.longitude));
  }

  void _choose(Place p) {
    if (widget.pickOnly) {
      Navigator.pop(context, p);
      return;
    }
    if (_editingPickup) {
      setState(() {
        _pickup = p;
        _editingPickup = false;
        _query.clear();
        _results = FreetownPlaces.all.take(8).toList();
      });
      _focus.requestFocus();
      return;
    }
    final pickup = _pickup ?? FreetownPlaces.all[1];
    go(context, ChooseRideScreen(pickup: pickup, dropoff: p, forSomeoneElse: widget.forSomeoneElse), replace: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 18, 0),
            child: Row(children: [
              const FtrBackButton(),
              Text(widget.title ?? (widget.forSomeoneElse ? 'Book for someone' : 'Plan your ride'), style: FtrText.h2),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: FtrCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
              child: Column(children: [
                if (!widget.pickOnly) ...[
                  _Row(
                    dot: FtrColors.green,
                    child: InkWell(
                      onTap: () => setState(() {
                        _editingPickup = true;
                        _focus.requestFocus();
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Pickup', style: FtrText.small),
                              Text(_pickup?.address ?? 'Choose pickup', maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.title),
                            ]),
                          ),
                          Text('Change', style: FtrText.link.copyWith(fontSize: 14)),
                        ]),
                      ),
                    ),
                  ),
                  const Divider(indent: 34),
                ],
                _Row(
                  dot: _editingPickup ? FtrColors.green : FtrColors.blue,
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    autofocus: true,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    style: FtrText.title.copyWith(fontSize: 17),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: _editingPickup ? 'Search pickup point' : (widget.pickOnly ? 'Search an area or address' : 'Where to?'),
                      hintStyle: FtrText.title.copyWith(fontSize: 17, color: FtrColors.faint),
                      suffixIcon: _searching
                          ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                          : (_query.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  onPressed: () {
                                    _query.clear();
                                    _onChanged('');
                                  },
                                  icon: const Icon(Icons.close_rounded))),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                if (_editingPickup || widget.pickOnly)
                  _ResultTile(icon: Icons.my_location_rounded, color: FtrColors.blue, title: 'Use my current location', subtitle: 'GPS', onTap: _useCurrentLocation),
                if (!_editingPickup && _saved.isNotEmpty && _query.text.isEmpty) ...[
                  for (final s in _saved)
                    _ResultTile(
                      icon: s.label == 'Home' ? Icons.home_rounded : (s.label == 'Work' ? Icons.work_rounded : Icons.star_rounded),
                      color: FtrColors.blue,
                      title: s.label,
                      subtitle: s.address,
                      onTap: () => _choose(s.place),
                    ),
                  const Divider(height: 24),
                ],
                if (_query.text.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Popular in Freetown', style: FtrText.small)),
                for (final p in _results)
                  _ResultTile(icon: Icons.location_on_rounded, color: FtrColors.muted, title: p.address, subtitle: p.subtitle ?? 'Freetown', onTap: () => _choose(p)),
                if (_results.isEmpty && !_searching)
                  const FtrEmptyState(icon: Icons.search_off_rounded, title: 'No places found', message: 'Try a nearby landmark, street or area name.'),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.dot, required this.child});
  final Color dot;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dot, width: 4.5))),
        const SizedBox(width: 18),
        Expanded(child: child),
      ]);
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color == FtrColors.muted ? FtrColors.body : color),
        ),
        title: Text(title, style: FtrText.title.copyWith(fontSize: 16)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.small),
      );
}
