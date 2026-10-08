import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colours sampled from the FreeTongRide mockups.
abstract final class FtrColors {
  // Brand
  static const blue = Color(0xFF1A5CFF);
  static const blueDeep = Color(0xFF0B47E6);
  static const blueBright = Color(0xFF2F7BFF);
  static const green = Color(0xFF19B868);
  static const greenBright = Color(0xFF22D36F);
  static const navy = Color(0xFF0B1442);
  static const purple = Color(0xFF7A45F0);
  static const orange = Color(0xFFFFA51F);
  static const red = Color(0xFFE5484D);
  static const star = Color(0xFFFFB020);

  // Text
  static const ink = navy;
  static const body = Color(0xFF3D4660);
  static const muted = Color(0xFF6B7489);
  static const faint = Color(0xFF9AA2B5);

  // Surfaces
  static const background = Color(0xFFF6F9FF);
  static const surface = Colors.white;
  static const border = Color(0xFFE6EBF4);
  static const divider = Color(0xFFEEF1F7);

  // Soft tints used behind icons and on tiles
  static const blueSoft = Color(0xFFEAF1FF);
  static const greenSoft = Color(0xFFE5F8EE);
  static const purpleSoft = Color(0xFFF1EBFF);
  static const orangeSoft = Color(0xFFFFF4E1);
  static const redSoft = Color(0xFFFDECEC);

  static const primaryGradient = LinearGradient(
    colors: [blueBright, blueDeep],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const walletGradient = LinearGradient(
    colors: [Color(0xFF0B3FD1), Color(0xFF1666FF), Color(0xFF0A2E9E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const brandGradient = LinearGradient(
    colors: [greenBright, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class FtrText {
  static const family = 'PlusJakartaSans';
  static const package = 'ftr_core';

  static const display = TextStyle(fontFamily: family, package: package, fontSize: 32, height: 1.12, fontWeight: FontWeight.w800, color: FtrColors.ink, letterSpacing: -0.8);
  static const h1 = TextStyle(fontFamily: family, package: package, fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, color: FtrColors.ink, letterSpacing: -0.6);
  static const h2 = TextStyle(fontFamily: family, package: package, fontSize: 21, height: 1.2, fontWeight: FontWeight.w800, color: FtrColors.ink, letterSpacing: -0.3);
  static const h3 = TextStyle(fontFamily: family, package: package, fontSize: 17, height: 1.25, fontWeight: FontWeight.w700, color: FtrColors.ink, letterSpacing: -0.2);
  static const title = TextStyle(fontFamily: family, package: package, fontSize: 15.5, height: 1.3, fontWeight: FontWeight.w700, color: FtrColors.ink);
  static const body = TextStyle(fontFamily: family, package: package, fontSize: 15, height: 1.45, fontWeight: FontWeight.w500, color: FtrColors.body);
  static const bodyMuted = TextStyle(fontFamily: family, package: package, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500, color: FtrColors.muted);
  static const small = TextStyle(fontFamily: family, package: package, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500, color: FtrColors.muted);
  static const label = TextStyle(fontFamily: family, package: package, fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: FtrColors.ink);
  static const button = TextStyle(fontFamily: family, package: package, fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.1);
  static const link = TextStyle(fontFamily: family, package: package, fontSize: 15, fontWeight: FontWeight.w700, color: FtrColors.blue);
}

abstract final class FtrTheme {
  static ThemeData light({Color seed = FtrColors.blue}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: seed,
      secondary: FtrColors.green,
      surface: FtrColors.surface,
      error: FtrColors.red,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'packages/${FtrText.package}/${FtrText.family}',
      scaffoldBackgroundColor: FtrColors.background,
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: FtrColors.ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      textTheme: base.textTheme.apply(bodyColor: FtrColors.body, displayColor: FtrColors.ink),
      dividerTheme: const DividerThemeData(color: FtrColors.divider, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FtrColors.navy,
        contentTextStyle: FtrText.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: FtrColors.border, width: 1.6),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: seed, selectionHandleColor: seed),
    );
  }
}

/// Soft card shadow used on tiles and fields.
const ftrSoftShadow = [
  BoxShadow(color: Color(0x0A1A3C8C), blurRadius: 14, offset: Offset(0, 3)),
];

/// Glow under primary buttons.
const ftrButtonShadow = [
  BoxShadow(color: Color(0x331A5CFF), blurRadius: 18, offset: Offset(0, 8)),
];
