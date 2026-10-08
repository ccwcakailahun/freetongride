// Renders key driver screens to PNG (build/screens/) for design review.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:ftr_driver/screens/auth/sign_in_screen.dart';
import 'package:ftr_driver/screens/home/account_tab.dart';
import 'package:ftr_driver/screens/home/driver_home_tab.dart';
import 'package:ftr_driver/screens/home/earnings_tab.dart';
import 'package:ftr_driver/screens/onboarding/documents_screen.dart';
import 'package:ftr_driver/screens/onboarding/review_status_screen.dart';
import 'package:ftr_driver/screens/trip/driver_trip_screen.dart';
import 'package:ftr_driver/state/driver_controller.dart';
import 'package:provider/provider.dart';

Future<void> _loadFonts() async {
  final jakarta = FontLoader('packages/ftr_core/PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(rootBundle.load('packages/ftr_core/assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await jakarta.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

final _profile = {
  'status': 'UnderReview', 'serviceId': 's3', 'serviceName': 'Car', 'vehicleMake': 'Toyota', 'vehicleModel': 'Corolla',
  'vehicleColor': 'White', 'vehicleYear': 2016, 'plateNumber': 'AFS 284', 'isOnline': false, 'completedTrips': 320,
  'documents': [
    {'id': '1', 'type': 'DrivingLicence', 'fileUrl': '/x.jpg', 'approved': null},
    {'id': '2', 'type': 'NationalId', 'fileUrl': '/y.jpg', 'approved': null},
  ],
  'missingDocuments': ['ProfilePhoto', 'VehiclePhoto'],
};

final _ride = {
  'id': 'r1', 'code': 'FTR-8K2Q4', 'status': 'DriverArrived', 'serviceName': 'Car', 'serviceId': 's1',
  'pickup': {'address': 'Lumley Beach', 'lat': 8.4207, 'lng': -13.293},
  'dropoff': {'address': 'Freetown Central', 'lat': 8.4844, 'lng': -13.2344},
  'distanceKm': 8.4, 'durationMinutes': 18, 'estimatedFare': 90, 'offeredFare': 90, 'agreedFare': 90,
  'fareDue': 90, 'paymentMethod': 'Cash', 'paymentStatus': 'Unpaid',
  'passenger': {'id': 'p', 'fullName': 'Mariama Kamara', 'phone': '+23276123456', 'rating': 4.9, 'ratingCount': 12},
  'createdAt': '2025-08-12T10:20:00Z',
};

void main() {
  final out = Directory('build/screens')..createSync(recursive: true);
  setUpAll(_loadFonts);

  final screens = <String, (Widget Function(), void Function(DriverController))>{
    'd01_sign_in': (() => const SignInScreen(), (_) {}),
    'd02_sign_up': (() => const DriverSignUpScreen(), (_) {}),
    'd03_documents': (() => const DocumentsScreen(), (_) {}),
    'd04_review': (() => const ReviewStatusScreen(), (_) {}),
    'd05_home_offline': (() => const DriverHomeTab(), (_) {}),
    'd06_home_requests': (
      () => const DriverHomeTab(),
      (dc) {
        dc.online = true;
        dc.requests = [
          RideRequest.fromJson({
            'rideId': 'r9', 'code': 'FTR-Q7', 'serviceName': 'Car',
            'pickup': {'address': 'Lumley Beach', 'lat': 8.4207, 'lng': -13.293},
            'dropoff': {'address': 'Freetown Central', 'lat': 8.4844, 'lng': -13.2344},
            'distanceKm': 8.4, 'durationMinutes': 18, 'pickupDistanceKm': 0.8, 'offeredFare': 90, 'estimatedFare': 90,
            'paymentMethod': 'Cash', 'passengerName': 'Mariama Kamara', 'passengerRating': 4.9, 'createdAt': '2025-08-12T10:20:00Z',
          })
        ];
      }
    ),
    'd07_trip_code': (() => const DriverTripScreen(), (dc) => dc.ride = Ride.fromJson(_ride)),
    'd08_earnings': (() => const EarningsTab(), (_) {}),
    'd09_account': (() => const DriverAccountTab(), (_) {}),
  };

  for (final e in screens.entries) {
    testWidgets('render ${e.key}', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.5, 915 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final session = Session(role: UserRole.driver, client: ApiClient(baseUrl: 'http://127.0.0.1:9'))
        ..setUser(AppUser.fromJson({
          'id': 'd', 'fullName': 'Mohamed Koroma', 'phone': '+23277123456', 'role': 'Driver', 'phoneVerified': true,
          'walletBalance': 114.65, 'points': 0, 'rating': 4.9, 'ratingCount': 320,
        }));
      final dc = DriverController(session)..profile = DriverProfile.fromJson(_profile);
      e.value.$2(dc);
      final key = GlobalKey();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: dc),
          Provider(create: (_) => PlacesService()),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: FtrTheme.light(seed: FtrColors.green), home: Scaffold(body: e.value.$1())),
        ),
      ));
      await tester.runAsync(() async {
        for (final el in find.byType(Image).evaluate()) {
          await precacheImage((el.widget as Image).image, el);
        }
      });
      await tester.pump(const Duration(milliseconds: 800));
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 1.6);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
