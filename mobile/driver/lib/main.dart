import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import 'screens/auth/splash_screen.dart';
import 'state/driver_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  final session = Session(role: UserRole.driver);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => DriverController(session)),
        Provider(create: (_) => PlacesService()),
      ],
      child: const DriverApp(),
    ),
  );
}

/// Driver app accent: green lead colour, blue as the secondary.
abstract final class DriverStyle {
  static const gradient = LinearGradient(colors: [Color(0xFF22C873), Color(0xFF0E9F5C)], begin: Alignment.centerLeft, end: Alignment.centerRight);
  static const accent = FtrColors.green;
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FreeTongRide Driver',
        debugShowCheckedModeBanner: false,
        theme: FtrTheme.light(seed: FtrColors.green),
        home: const SplashScreen(),
      );
}

Future<T?> go<T>(BuildContext context, Widget page, {bool replace = false, bool clear = false}) {
  final route = MaterialPageRoute<T>(builder: (_) => page);
  final nav = Navigator.of(context);
  if (clear) return nav.pushAndRemoveUntil(route, (_) => false);
  if (replace) return nav.pushReplacement(route);
  return nav.push(route);
}

/// Green primary button used throughout the driver app.
class DriverButton extends StatelessWidget {
  const DriverButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon, this.showArrow = true, this.height = 60});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool showArrow;
  final double height;

  @override
  Widget build(BuildContext context) =>
      FtrPrimaryButton(label: label, onPressed: onPressed, loading: loading, icon: icon, showArrow: showArrow, gradient: DriverStyle.gradient, height: height);
}
