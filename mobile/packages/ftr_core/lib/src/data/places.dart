import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Well-known places in Freetown, used for instant search and "Popular destinations".
/// Coordinates are approximate centres.
abstract final class FreetownPlaces {
  static const centre = LatLng(8.4657, -13.2317);

  static const all = <Place>[
    Place('Freetown Central', 8.4844, -13.2344, subtitle: 'Cotton Tree, Siaka Stevens Street'),
    Place('Lumley Beach', 8.4207, -13.2930, subtitle: 'Lumley Beach Road'),
    Place('Aberdeen', 8.4400, -13.2810, subtitle: 'Aberdeen, Western Area'),
    Place('Kissy', 8.4734, -13.1946, subtitle: 'East End, Freetown'),
    Place('Wilberforce', 8.4677, -13.2575, subtitle: 'Wilberforce, West End'),
    Place('Congo Cross', 8.4706, -13.2546, subtitle: 'Main Motor Road'),
    Place('Lumley', 8.4167, -13.2711, subtitle: 'Lumley Roundabout'),
    Place('Murray Town', 8.4600, -13.2700, subtitle: 'Murray Town, West End'),
    Place('Hill Station', 8.4590, -13.2390, subtitle: 'Hill Station, Freetown'),
    Place('Brookfields', 8.4710, -13.2440, subtitle: 'Brookfields, Freetown'),
    Place('Tower Hill', 8.4790, -13.2330, subtitle: 'Parliament, Tower Hill'),
    Place('Goderich', 8.4050, -13.2880, subtitle: 'Goderich, Western Area'),
    Place('Juba', 8.4290, -13.2550, subtitle: 'Juba Hill'),
    Place('Regent', 8.4230, -13.2200, subtitle: 'Regent, Mountain Rural'),
    Place('Wellington', 8.4469, -13.1617, subtitle: 'Wellington, East End'),
    Place('Calaba Town', 8.4380, -13.1530, subtitle: 'Calaba Town, East End'),
    Place('Fourah Bay College', 8.4799, -13.2183, subtitle: 'Mount Aureol'),
    Place('National Stadium', 8.4690, -13.2450, subtitle: 'Brookfields'),
    Place('Big Market', 8.4880, -13.2350, subtitle: 'Wallace Johnson Street'),
    Place('Connaught Hospital', 8.4888, -13.2367, subtitle: 'Wilberforce Street'),
  ];

  /// Popular destinations on the Home screen, with their mockup photos.
  static const popular = <(Place, String)>[
    (Place('Aberdeen', 8.4400, -13.2810), 'dest_aberdeen.png'),
    (Place('Freetown Central', 8.4844, -13.2344), 'dest_freetown_central.png'),
    (Place('Kissy', 8.4734, -13.1946), 'dest_kissy.png'),
    (Place('Wilberforce', 8.4677, -13.2575), 'dest_wilberforce.png'),
  ];
}

/// Search, reverse geocoding and routes from OpenStreetMap services.
/// Swap for Google Places / Directions once a Maps key is configured.
class PlacesService {
  static const _ua = {'User-Agent': 'FreeTongRide/1.0 (ride-hailing app, Freetown)'};
  final _http = http.Client();

  Future<List<Place>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return FreetownPlaces.all.take(8).toList();
    final local = FreetownPlaces.all.where((p) => p.address.toLowerCase().contains(q) || (p.subtitle?.toLowerCase().contains(q) ?? false)).toList();
    if (q.length < 3) return local;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': 'sl',
        'viewbox': '-13.33,8.52,-13.08,8.36',
        'bounded': '1',
      });
      final res = await _http.get(uri, headers: _ua).timeout(const Duration(seconds: 8));
      final list = (jsonDecode(res.body) as List).map((e) {
        final parts = (e['display_name'] as String).split(', ');
        return Place(e['name']?.toString().isNotEmpty == true ? e['name'] : parts.first, double.parse(e['lat']), double.parse(e['lon']),
            subtitle: parts.skip(1).take(2).join(', '));
      });
      final seen = local.map((p) => p.address.toLowerCase()).toSet();
      return [...local, ...list.where((p) => seen.add(p.address.toLowerCase()))];
    } catch (_) {
      return local;
    }
  }

  Future<String> nameFor(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {'lat': '$lat', 'lon': '$lng', 'format': 'jsonv2', 'zoom': '16'});
      final res = await _http.get(uri, headers: _ua).timeout(const Duration(seconds: 6));
      final j = jsonDecode(res.body);
      final a = j['address'] as Map<String, dynamic>? ?? {};
      final name = a['road'] ?? a['neighbourhood'] ?? a['suburb'] ?? j['name'];
      final area = a['suburb'] ?? a['city_district'] ?? a['city'];
      if (name != null) return area != null && area != name ? '$name, $area' : '$name';
    } catch (_) {}
    // Nearest known place as a fallback.
    final d = const Distance();
    final nearest = FreetownPlaces.all.reduce((a, b) =>
        d(LatLng(lat, lng), LatLng(a.lat, a.lng)) < d(LatLng(lat, lng), LatLng(b.lat, b.lng)) ? a : b);
    return 'Near ${nearest.address}';
  }

  /// Road route between two points; a straight line if the routing service is unavailable.
  Future<List<LatLng>> route(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson');
      final res = await _http.get(uri, headers: _ua).timeout(const Duration(seconds: 8));
      final coords = jsonDecode(res.body)['routes'][0]['geometry']['coordinates'] as List;
      return coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
    } catch (_) {
      return [from, to];
    }
  }
}

/// Current position with permission handling. Returns null if the person said no.
class LocationService {
  static Future<bool> hasPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  static Future<Position?> current() async {
    try {
      if (!await hasPermission()) return null;
      return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  static Stream<Position> track({int distanceFilter = 15}) =>
      Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilter));
}

/// Same estimates the API uses (Geo.cs): road distance ≈ straight line × 1.3, average 22 km/h in town.
abstract final class Geo {
  static const roadFactor = 1.3;
  static const kmh = 22.0;
}
