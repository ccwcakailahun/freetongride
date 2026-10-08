// Renders the main passenger screens to PNG (build/screens/) for design review.
// Run: flutter test test/render_screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:ftr_passenger/screens/home/account_tab.dart';
import 'package:ftr_passenger/screens/home/activity_tab.dart';
import 'package:ftr_passenger/screens/home/home_tab.dart';
import 'package:ftr_passenger/screens/home/wallet_tab.dart';
import 'package:ftr_passenger/screens/onboarding/complete_profile_screen.dart';
import 'package:ftr_passenger/screens/onboarding/create_account_screen.dart';
import 'package:ftr_passenger/screens/onboarding/create_password_screen.dart';
import 'package:ftr_passenger/screens/onboarding/location_permission_screen.dart';
import 'package:ftr_passenger/screens/onboarding/notifications_permission_screen.dart';
import 'package:ftr_passenger/screens/onboarding/otp_screen.dart';
import 'package:ftr_passenger/screens/onboarding/sign_in_screen.dart';
import 'package:ftr_passenger/screens/onboarding/splash_screen.dart';
import 'package:ftr_passenger/screens/onboarding/verify_phone_screen.dart';
import 'package:ftr_passenger/screens/ride/trip_complete_screen.dart';
import 'package:ftr_passenger/state/ride_controller.dart';
import 'package:provider/provider.dart';

Future<void> _loadFonts() async {
  final jakarta = FontLoader('packages/ftr_core/PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(rootBundle.load('packages/ftr_core/assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('${const String.fromEnvironment('FLUTTER_ROOT', defaultValue: 'C:/flutter')}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

final _user = AppUser.fromJson({
  'id': '00000000-0000-0000-0000-000000000001',
  'fullName': 'Mariama Kamara',
  'phone': '+23276123456',
  'email': 'mariama@example.com',
  'role': 'Passenger',
  'phoneVerified': true,
  'emergencyContact': '+23276999888',
  'homeArea': 'Lumley Beach, Freetown',
  'walletBalance': 150,
  'points': 320,
  'rating': 4.9,
  'ratingCount': 12,
});

Map<String, dynamic> _ride(String status) => {
      'id': 'r1', 'code': 'FTR-8K2Q4', 'status': status, 'serviceName': 'Car', 'serviceId': 's1',
      'pickup': {'address': 'Lumley Beach', 'lat': 8.4207, 'lng': -13.293},
      'dropoff': {'address': 'Freetown Central', 'lat': 8.4844, 'lng': -13.2344},
      'distanceKm': 8.4, 'durationMinutes': 18, 'estimatedFare': 90, 'offeredFare': 90, 'agreedFare': 90,
      'fareDue': 90, 'commission': 13.5, 'paymentMethod': 'Wallet', 'paymentStatus': 'Paid', 'pickupCode': '482913',
      'passenger': {'id': 'p', 'fullName': 'Mariama Kamara', 'phone': '+23276123456', 'rating': 4.9, 'ratingCount': 12},
      'driver': {
        'id': 'd', 'fullName': 'Mohamed Koroma', 'phone': '+23277123456', 'rating': 4.9, 'ratingCount': 320, 'completedTrips': 320,
        'vehicle': 'Toyota Corolla • White • AFS 284'
      },
      'createdAt': '2025-08-12T10:20:00Z', 'startedAt': '2025-08-12T10:24:00Z', 'endedAt': '2025-08-12T10:42:00Z',
    };

void main() {
  final out = Directory('build/screens')..createSync(recursive: true);

  setUpAll(() async {
    await _loadFonts();
  });

  final screens = <String, Widget Function()>{
    '00_splash': () => const SplashScreen(),
    '12_sign_in': () => const SignInScreen(),
    '13_create_account': () => const CreateAccountScreen(),
    '14_verify_phone': () => const VerifyPhoneScreen(),
    '15_otp': () => OtpScreen(sent: OtpSent.fromJson({'phone': '+23276123456', 'resendAfterSeconds': 58})),
    '16_create_password': () => const CreatePasswordScreen(phone: '+23276123456', code: '123456'),
    '17_location': () => const LocationPermissionScreen(),
    '18_notifications': () => const NotificationsPermissionScreen(),
    '19_complete_profile': () => const CompleteProfileScreen(),
    '01_home': () => const HomeTab(),
    '07_trip_complete': () => TripCompleteScreen(ride: Ride.fromJson(_ride('Completed')), fromHistory: true),
    '08_activity': () => const ActivityTab(),
    '09_wallet': () => const WalletTab(),
    '10_account': () => const AccountTab(),
  };

  for (final entry in screens.entries) {
    testWidgets('render ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.5, 915 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final session = Session(role: UserRole.passenger, client: ApiClient(baseUrl: 'http://127.0.0.1:9'))..setUser(_user);
      final key = GlobalKey();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider(create: (_) => RideController(session)),
          Provider(create: (_) => PlacesService()),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: FtrTheme.light(), home: Scaffold(body: entry.value())),
        ),
      ));
      // Let images decode.
      await tester.runAsync(() async {
        for (final el in find.byType(Image).evaluate()) {
          await precacheImage((el.widget as Image).image, el);
        }
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.6);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${entry.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      // Stop timers (OTP countdown, splash) before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
