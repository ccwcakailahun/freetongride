import 'package:flutter/material.dart';

import 'theme.dart';

/// Image from this package's assets/images folder.
Image ftrImage(String name, {double? width, double? height, BoxFit fit = BoxFit.cover, Alignment alignment = Alignment.center}) =>
    Image.asset('assets/images/$name', package: 'ftr_core', width: width, height: height, fit: fit, alignment: alignment);

/// The F-road mark.
class FtrLogoMark extends StatelessWidget {
  const FtrLogoMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) =>
      ftrImage('logo_mark.png', width: size * 0.93, height: size, fit: BoxFit.contain);
}

/// Logo mark + "FreeTongRide" + "Moving Freetown Together", as on every screen header.
class FtrBrandHeader extends StatelessWidget {
  const FtrBrandHeader({super.key, this.size = FtrBrandSize.large, this.subtitle});
  final FtrBrandSize size;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final (mark, title, tag, gap) = switch (size) {
      FtrBrandSize.large => (78.0, 34.0, 12.5, 12.0),
      FtrBrandSize.medium => (62.0, 28.0, 11.0, 10.0),
      FtrBrandSize.compact => (40.0, 21.0, 8.2, 6.0),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FtrLogoMark(size: mark),
        SizedBox(width: gap),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [FtrColors.blue, FtrColors.blueDeep]).createShader(r),
              child: Text('FreeTongRide',
                  style: FtrText.h1.copyWith(fontSize: title, color: Colors.white, letterSpacing: -0.9, height: 1.0)),
            ),
            SizedBox(height: size == FtrBrandSize.compact ? 2 : 5),
            Text(subtitle ?? 'Moving Freetown Together',
                style: FtrText.small.copyWith(
                    fontSize: tag, color: FtrColors.navy, fontWeight: FontWeight.w600, letterSpacing: tag * 0.18, height: 1)),
          ],
        ),
      ],
    );
  }
}

enum FtrBrandSize { large, medium, compact }

/// Soft blue background with faint white swooshes, used behind the onboarding screens.
class FtrBackground extends StatelessWidget {
  const FtrBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FF), Color(0xFFF6F9FF), Color(0xFFF9FBFF)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: CustomPaint(painter: _SwooshPainter(), child: child),
    );
  }
}

class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final top = Path()
      ..moveTo(0, s.height * 0.10)
      ..quadraticBezierTo(s.width * 0.55, s.height * 0.02, s.width, s.height * 0.16)
      ..lineTo(s.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(top, p);
    final mid = Path()
      ..moveTo(0, s.height * 0.62)
      ..quadraticBezierTo(s.width * 0.35, s.height * 0.52, s.width, s.height * 0.58)
      ..lineTo(s.width, s.height * 0.66)
      ..quadraticBezierTo(s.width * 0.4, s.height * 0.6, 0, s.height * 0.70)
      ..close();
    canvas.drawPath(mid, p..color = Colors.white.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hero photo that fades into the page with a wave at the bottom (images already carry the wave).
class FtrHero extends StatelessWidget {
  const FtrHero(this.image, {super.key, this.height});
  final String image;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black, Colors.black],
        stops: [0, 0.14, 1],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: ftrImage(image, height: height, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter),
    );
  }
}

/// Main-tab app bar: menu, centred brand, bell with an unread dot.
class FtrTopBar extends StatelessWidget {
  const FtrTopBar({super.key, this.onMenu, this.onBell, this.hasUnread = true, this.leading});
  final VoidCallback? onMenu;
  final VoidCallback? onBell;
  final bool hasUnread;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          leading ??
              IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded, size: 30, color: FtrColors.ink),
                tooltip: 'Menu',
              ),
          const Expanded(child: Center(child: FtrBrandHeader(size: FtrBrandSize.compact))),
          FtrBellButton(onTap: onBell, hasUnread: hasUnread),
        ],
      ),
    );
  }
}

class FtrBellButton extends StatelessWidget {
  const FtrBellButton({super.key, this.onTap, this.hasUnread = true});
  final VoidCallback? onTap;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Notifications',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 30, color: FtrColors.ink),
          if (hasUnread)
            Positioned(
              right: 2,
              top: 1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: FtrColors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.6)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Back chevron used at the top-left of flow screens.
class FtrBackButton extends StatelessWidget {
  const FtrBackButton({super.key, this.label, this.onTap});
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tap = onTap ?? () => Navigator.of(context).maybePop();
    if (label == null) {
      return IconButton(onPressed: tap, tooltip: 'Back', icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: FtrColors.ink));
    }
    return TextButton.icon(
      onPressed: tap,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: FtrColors.blue),
      label: Text(label!, style: FtrText.link.copyWith(fontSize: 17)),
    );
  }
}
