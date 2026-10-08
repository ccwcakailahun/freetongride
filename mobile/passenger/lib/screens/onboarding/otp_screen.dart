import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import 'create_password_screen.dart';
import 'flow.dart';

/// Canvas 15 — Enter verification code.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.sent, this.resetPassword = false});
  final OtpSent sent;
  final bool resetPassword;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  late OtpSent _sent = widget.sent;
  late int _seconds = widget.sent.resendAfterSeconds;
  Timer? _timer;
  bool _busy = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Development builds get the code back from the API; show it so testers are not stuck without SMS.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sent.devCode != null && mounted) showToast(context, 'Development code: ${_sent.devCode}', icon: Icons.developer_mode_rounded);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 0) return t.cancel();
      setState(() => _seconds--);
    });
  }

  Future<void> _resend() async {
    try {
      final s = await context.read<Session>().api.sendOtp(_sent.phone, reset: widget.resetPassword);
      setState(() {
        _sent = s;
        _seconds = s.resendAfterSeconds;
        _code.clear();
        _error = false;
      });
      _startTimer();
      if (mounted) showToast(context, s.devCode != null ? 'New code sent. Development code: ${s.devCode}' : 'We sent you a new code.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _verify([String? value]) async {
    final code = value ?? _code.text;
    if (code.length != 6) {
      setState(() => _error = true);
      return;
    }
    if (widget.resetPassword) {
      go(context, CreatePasswordScreen(phone: _sent.phone, code: code));
      return;
    }
    setState(() {
      _busy = true;
      _error = false;
    });
    final session = context.read<Session>();
    try {
      final r = await session.api.verifyPhone(_sent.phone, code);
      await session.signIn(r);
      if (mounted) await continueAfterSignIn(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
      showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            children: [
              const Align(alignment: Alignment.centerLeft, child: FtrBackButton()),
              const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
              const SizedBox(height: 14),
              SizedBox(height: 220, child: ftrImage('illus_otp.png', fit: BoxFit.contain)),
              const SizedBox(height: 18),
              Text('Enter verification code', textAlign: TextAlign.center, style: FtrText.h1.copyWith(fontSize: 30)),
              const SizedBox(height: 10),
              Text('We sent a 6-digit code to', textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5)),
              const SizedBox(height: 4),
              Text(prettyPhone(_sent.phone), textAlign: TextAlign.center, style: FtrText.h3.copyWith(fontSize: 20)),
              const SizedBox(height: 26),
              FtrCodeInput(controller: _code, error: _error, onCompleted: _verify, onChanged: (_) => setState(() => _error = false)),
              const SizedBox(height: 24),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Resend code in '),
                  TextSpan(text: '$mm:$ss', style: FtrText.title.copyWith(color: FtrColors.blue, fontSize: 16)),
                ]),
                textAlign: TextAlign.center,
                style: FtrText.bodyMuted.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Center(child: FtrLink('Resend code', underline: true, onTap: _seconds > 0 ? null : _resend)),
              const SizedBox(height: 20),
              FtrPrimaryButton(label: widget.resetPassword ? 'Continue' : 'Verify & Continue', loading: _busy, onPressed: () => _verify()),
              const SizedBox(height: 14),
              Center(child: FtrLink('Edit phone number', onTap: () => Navigator.pop(context))),
              const SizedBox(height: 22),
              const FtrSafetyBanner(
                compact: true,
                title: 'Your security matters',
                message: 'We use verification codes to keep your account safe and secure.',
                icon: Icons.verified_user_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
