import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import 'splash_screen.dart';

/// Driver sign in (Canvas 12 in driver green).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      await session.signIn(await session.api.login(_phone.text, _password.text, role: UserRole.driver));
      if (mounted) await routeDriver(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.needsVerification) {
        final sent = await session.api.sendOtp(_phone.text);
        if (mounted) go(context, DriverOtpScreen(sent: sent));
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: FtrFitScreen(padding: EdgeInsets.zero, children: [
            const SizedBox(height: 18),
            const Center(child: FtrBrandHeader(size: FtrBrandSize.medium, subtitle: 'Driver  •  Earn on your schedule')),
            const FtrHero('hero_signin.png', height: 230),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Drive with '),
                      TextSpan(text: 'us', style: FtrText.display.copyWith(color: FtrColors.green)),
                    ]),
                    textAlign: TextAlign.center,
                    style: FtrText.display.copyWith(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  Text('Sign in to go online and start earning across Freetown.', textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5)),
                  const SizedBox(height: 24),
                  FtrPlainField(
                    hint: 'Phone number',
                    prefix: const FtrCountryCode(),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: phoneFormatters,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                  ),
                  const SizedBox(height: 14),
                  FtrPlainField(hint: 'Password', icon: Icons.lock_outline_rounded, controller: _password, obscure: true, onSubmitted: (_) => _signIn()),
                  const SizedBox(height: 22),
                  DriverButton(label: 'Sign In', loading: _busy, onPressed: _signIn),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('New driver?', style: FtrText.bodyMuted.copyWith(fontSize: 15.5)),
                    FtrLink('Create a driver account', onTap: () => go(context, const DriverSignUpScreen())),
                  ]),
                  const SizedBox(height: 16),
                  const FtrSafetyBanner(
                    compact: true,
                    title: 'Verified drivers only',
                    message: 'We check every licence and vehicle before a driver can go online.',
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Driver sign up (Canvas 13 in driver green).
class DriverSignUpScreen extends StatefulWidget {
  const DriverSignUpScreen({super.key});

  @override
  State<DriverSignUpScreen> createState() => _DriverSignUpScreenState();
}

class _DriverSignUpScreenState extends State<DriverSignUpScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final sent = await context.read<Session>().api.register(
            fullName: _name.text.trim(),
            phone: _phone.text,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            password: _password.text,
            role: UserRole.driver,
          );
      if (mounted) go(context, DriverOtpScreen(sent: sent));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: FtrFitScreen(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
            const Align(alignment: Alignment.centerLeft, child: FtrBackButton()),
            const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Become a '),
                TextSpan(text: 'driver', style: FtrText.display.copyWith(color: FtrColors.green)),
              ]),
              textAlign: TextAlign.center,
              style: FtrText.display.copyWith(fontSize: 34),
            ),
            const SizedBox(height: 8),
            Text('Create your account, add your vehicle and documents, and we will review them.',
                textAlign: TextAlign.center, style: FtrText.body.copyWith(color: FtrColors.muted, fontSize: 16)),
            const SizedBox(height: 22),
            FtrIconField(icon: Icons.person_outline_rounded, label: 'Full name (as on licence)', hint: 'e.g. Mohamed Koroma', controller: _name, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            FtrIconField(icon: Icons.call_outlined, label: 'Phone number', hint: 'e.g. 77 123 456', controller: _phone, keyboardType: TextInputType.phone, inputFormatters: phoneFormatters),
            const SizedBox(height: 12),
            FtrIconField(icon: Icons.mail_outline_rounded, label: 'Email address (optional)', hint: 'e.g. mohamed@email.com', controller: _email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            FtrIconField(icon: Icons.lock_outline_rounded, label: 'Password', hint: '8+ characters, a number and a capital', controller: _password, obscure: true),
            const SizedBox(height: 22),
            DriverButton(label: 'Create Driver Account', loading: _busy, onPressed: _create),
            const SizedBox(height: 18),
            const Row(children: [
              Expanded(child: _Step(n: '1', label: 'Account')),
              Expanded(child: _Step(n: '2', label: 'Vehicle')),
              Expanded(child: _Step(n: '3', label: 'Documents')),
              Expanded(child: _Step(n: '4', label: 'Approval')),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.label});
  final String n;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: FtrColors.greenSoft, shape: BoxShape.circle, border: Border.all(color: FtrColors.green.withValues(alpha: 0.4))),
          child: Text(n, style: FtrText.title.copyWith(color: FtrColors.green)),
        ),
        const SizedBox(height: 6),
        Text(label, style: FtrText.small),
      ]);
}

/// Phone verification (Canvas 15).
class DriverOtpScreen extends StatefulWidget {
  const DriverOtpScreen({super.key, required this.sent});
  final OtpSent sent;

  @override
  State<DriverOtpScreen> createState() => _DriverOtpScreenState();
}

class _DriverOtpScreenState extends State<DriverOtpScreen> {
  final _code = TextEditingController();
  late OtpSent _sent = widget.sent;
  late int _seconds = widget.sent.resendAfterSeconds;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick();
    // Until SMS is connected the server returns the code (test mode); fill the boxes so the driver only taps Verify.
    if (_sent.devCode != null) _code.text = _sent.devCode!;
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 0) return t.cancel();
      setState(() => _seconds--);
    });
  }

  Future<void> _verify([String? v]) async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      await session.signIn(await session.api.verifyPhone(_sent.phone, v ?? _code.text));
      if (mounted) await routeDriver(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      final s = await context.read<Session>().api.sendOtp(_sent.phone);
      setState(() {
        _sent = s;
        _seconds = s.resendAfterSeconds;
        _code.text = s.devCode ?? '';
      });
      _tick();
      if (mounted && s.devCode != null) showToast(context, 'New code filled in for you.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: FtrFitScreen(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
            const Align(alignment: Alignment.centerLeft, child: FtrBackButton()),
            const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
            SizedBox(height: 210, child: ftrImage('illus_otp.png', fit: BoxFit.contain)),
            const SizedBox(height: 12),
            Text('Enter verification code', textAlign: TextAlign.center, style: FtrText.h1),
            const SizedBox(height: 8),
            Text('We sent a 6-digit code to', textAlign: TextAlign.center, style: FtrText.body),
            Text(prettyPhone(_sent.phone), textAlign: TextAlign.center, style: FtrText.h3.copyWith(fontSize: 20)),
            const SizedBox(height: 24),
            FtrCodeInput(controller: _code, onCompleted: _verify),
            if (_sent.devCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: FtrColors.greenSoft, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded, color: FtrColors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('We filled in your code for you. Tap Verify & Continue.', style: FtrText.label.copyWith(color: FtrColors.green))),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: _seconds > 0
                  ? Text('Resend code in 00:${_seconds.toString().padLeft(2, '0')}', style: FtrText.bodyMuted)
                  : FtrLink('Resend code', underline: true, onTap: _resend),
            ),
            const SizedBox(height: 20),
            DriverButton(label: 'Verify & Continue', loading: _busy, onPressed: () => _verify()),
          ]),
        ),
      ),
    );
  }
}
