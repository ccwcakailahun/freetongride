import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import 'flow.dart';
import 'sign_in_screen.dart';

/// Logo on white with the green-blue wave, while the saved session is restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final session = context.read<Session>();
    await Future.wait([session.restore(), Future.delayed(const Duration(milliseconds: 1600))]);
    if (!mounted) return;
    if (session.signedIn) {
      await continueAfterSignIn(context);
    } else {
      go(context, const SignInScreen(), clear: true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(fade),
              child: ftrImage('splash_wave.png', width: double.infinity, fit: BoxFit.fitWidth),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.18),
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(fade),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ftrImage('logo_full.png', fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
