import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'theme.dart';

/// Light street map in the style of the mockups (OpenStreetMap data, CARTO Voyager tiles).
class FtrMap extends StatelessWidget {
  const FtrMap({
    super.key,
    this.controller,
    this.center,
    this.zoom = 13.5,
    this.route,
    this.markers = const [],
    this.fitPoints,
    this.interactive = true,
    this.padding = const EdgeInsets.all(60),
  });

  final MapController? controller;
  final LatLng? center;
  final double zoom;
  final List<LatLng>? route;
  final List<Marker> markers;

  /// When set, the camera fits these points instead of using [center]/[zoom].
  final List<LatLng>? fitPoints;
  final bool interactive;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final fit = fitPoints != null && fitPoints!.length > 1 ? CameraFit.coordinates(coordinates: fitPoints!, padding: padding, maxZoom: 16) : null;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center ?? const LatLng(8.4657, -13.2317),
        initialZoom: zoom,
        initialCameraFit: fit,
        interactionOptions: InteractionOptions(flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
        backgroundColor: const Color(0xFFEFF3F8),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.freetongride.app',
        ),
        if (route != null && route!.length > 1)
          PolylineLayer(polylines: [
            Polyline(points: route!, strokeWidth: 9, color: Colors.white.withValues(alpha: 0.9)),
            Polyline(points: route!, strokeWidth: 5.5, color: FtrColors.blue),
          ]),
        MarkerLayer(markers: markers),
        const _Attribution(),
      ],
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          color: Colors.white.withValues(alpha: 0.7),
          child: Text('© OpenStreetMap © CARTO', style: FtrText.small.copyWith(fontSize: 9)),
        ),
      );
}

/// Green teardrop pickup pin.
Marker pickupPin(LatLng p, {String? label, VoidCallback? onTap}) => _labelled(p, _Pin(color: FtrColors.green), label, onTap, pinStyle: true);

/// Blue ring drop-off marker.
Marker dropoffPin(LatLng p, {String? label, VoidCallback? onTap}) => _labelled(p, const _Ring(), label, onTap);

/// Pulsing "you are here" dot.
Marker youAreHere(LatLng p) => Marker(point: p, width: 70, height: 70, child: const _Pulse());

/// Top-down car rotated to the heading.
Marker carMarker(LatLng p, {double heading = 0, double size = 46}) => Marker(
      point: p,
      width: size,
      height: size,
      child: Transform.rotate(angle: heading * math.pi / 180, child: CustomPaint(painter: _CarPainter())),
    );

Marker _labelled(LatLng p, Widget icon, String? label, VoidCallback? onTap, {bool pinStyle = false}) {
  const w = 230.0;
  return Marker(
    point: p,
    width: w,
    height: 60,
    // Puts the icon (left 44 px of the widget) on the point; pins stand on it, rings centre on it.
    alignment: pinStyle ? const Alignment(0.81, -0.87) : const Alignment(0.81, 0),
    child: GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 44, height: 56, child: Align(alignment: pinStyle ? Alignment.bottomCenter : Alignment.center, child: icon)),
          if (label != null)
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 2),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: ftrSoftShadow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: FtrText.title.copyWith(fontSize: 14.5))),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 20, color: FtrColors.ink),
                ]),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(alignment: const Alignment(0, -0.35), children: [
        Icon(Icons.location_on, color: color, size: 50, shadows: const [Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))]),
        Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      ]);
}

class _Ring extends StatelessWidget {
  const _Ring();

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: FtrColors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: FtrColors.blue, width: 7)),
        ),
      );
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 24 + 46 * _c.value,
            height: 24 + 46 * _c.value,
            decoration: BoxDecoration(color: FtrColors.blue.withValues(alpha: 0.22 * (1 - _c.value)), shape: BoxShape.circle),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: FtrColors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: ftrSoftShadow,
            ),
          ),
        ]),
      );
}

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width * 0.48, h = s.height * 0.9;
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: s.center(Offset.zero), width: w, height: h), Radius.circular(w * 0.38));
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 4, true);
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.drawRRect(body, Paint()
      ..color = const Color(0xFFCBD3E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    final glass = Paint()..color = const Color(0xFF2A3550);
    final cx = s.width / 2, top = (s.height - h) / 2;
    // windscreen and rear window
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.36, top + h * 0.2, w * 0.72, h * 0.17), const Radius.circular(4)), glass);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.33, top + h * 0.72, w * 0.66, h * 0.11), const Radius.circular(3)), glass);
    // roof
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.34, top + h * 0.39, w * 0.68, h * 0.31), const Radius.circular(5)),
        Paint()..color = const Color(0xFFF2F5FA));
    // headlights
    final light = Paint()..color = const Color(0xFFFFE08A);
    canvas.drawCircle(Offset(cx - w * 0.3, top + h * 0.05), w * 0.07, light);
    canvas.drawCircle(Offset(cx + w * 0.3, top + h * 0.05), w * 0.07, light);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
