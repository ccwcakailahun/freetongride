import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding/splash_screen.dart';
import 'state/ride_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Screens are designed for portrait phones.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  final session = Session(role: UserRole.passenger);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => RideController(session)),
        Provider(create: (_) => PlacesService()),
      ],
      child: const PassengerApp(),
    ),
  );
}

final navigatorKey = GlobalKey<NavigatorState>();

class PassengerApp extends StatelessWidget {
  const PassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreeTongRide',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: FtrTheme.light(),
      home: const SplashScreen(),
    );
  }
}

/// Push with a gentle slide used across the app.
Future<T?> go<T>(BuildContext context, Widget page, {bool replace = false, bool clear = false}) {
  final route = PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, a, _, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved), child: child),
      );
    },
  );
  final nav = Navigator.of(context);
  if (clear) return nav.pushAndRemoveUntil(route, (_) => false);
  if (replace) return nav.pushReplacement(route);
  return nav.push(route);
}
