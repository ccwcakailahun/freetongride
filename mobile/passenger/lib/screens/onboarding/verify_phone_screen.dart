import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import 'otp_screen.dart';

/// Canvas 14 — Verify your phone number. Also the first step of "Forgot password?".
class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key, this.initialPhone, this.resetPassword = false});
  final String? initialPhone;
  final bool resetPassword;

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  late final _phone = TextEditingController(text: widget.initialPhone);
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final sent = await context.read<Session>().api.sendOtp(_phone.text, reset: widget.resetPassword);
      if (mounted) go(context, OtpScreen(sent: sent, resetPassword: widget.resetPassword));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reset = widget.resetPassword;
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(children: [
                const Padding(padding: EdgeInsets.only(top: 100), child: FtrHero('hero_verify_phone.png', height: 220)),
                const Positioned(top: 22, left: 0, right: 0, child: Center(child: FtrBrandHeader(size: FtrBrandSize.medium))),
                const Positioned(top: 4, left: 4, child: FtrBackButton()),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(reset ? 'Reset your' : 'Verify your', textAlign: TextAlign.center, style: FtrText.display.copyWith(fontSize: 36)),
                    Text(reset ? 'password' : 'phone number', textAlign: TextAlign.center, style: FtrText.display.copyWith(fontSize: 36, color: FtrColors.blue)),
                    const SizedBox(height: 10),
                    Text(
                      reset
                          ? "We'll send a code to your phone number so you can set a new password."
                          : "We'll send a verification code to your phone number to continue.",
                      textAlign: TextAlign.center,
                      style: FtrText.body.copyWith(fontSize: 16.5, color: FtrColors.muted),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: FtrColors.border, width: 1.2),
                        boxShadow: ftrSoftShadow,
                      ),
                      child: Row(children: [
                        const SierraLeoneFlag(size: 34),
                        const SizedBox(width: 16),
                        Expanded(child: Text('Sierra Leone', style: FtrText.title.copyWith(fontSize: 17, fontWeight: FontWeight.w600))),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: FtrColors.blue, size: 28),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: FtrColors.border, width: 1.2),
                        boxShadow: ftrSoftShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(children: [
                        Container(
                          width: 96,
                          color: const Color(0xFFF2F5FA),
                          alignment: Alignment.center,
                          child: Text('+232', style: FtrText.title.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: TextField(
                              controller: _phone,
                              autofocus: widget.initialPhone == null || widget.initialPhone!.isEmpty,
                              keyboardType: TextInputType.phone,
                              inputFormatters: phoneFormatters,
                              onSubmitted: (_) => _send(),
                              style: FtrText.body.copyWith(color: FtrColors.ink, fontSize: 17),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter your phone number',
                                hintStyle: FtrText.body.copyWith(color: FtrColors.faint, fontSize: 16.5),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    const FtrSafetyBanner(
                      compact: true,
                      icon: Icons.lock_rounded,
                      title: 'Helps keep our community safe',
                      message: 'Phone verification helps us confirm your identity, prevent fraud, and keep riders and drivers safe across Freetown.',
                    ),
                    const SizedBox(height: 22),
                    FtrPrimaryButton(label: 'Send Code', loading: _busy, onPressed: _send),
                    const SizedBox(height: 12),
                    Center(
                      child: FtrLink('Use email instead',
                          onTap: () => showToast(context, 'Email codes are coming soon. Use your phone number for now.', icon: Icons.info_outline_rounded)),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: FtrText.bodyMuted)),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(reset ? 'Remembered it?' : 'Already verified?', style: FtrText.bodyMuted.copyWith(fontSize: 15.5)),
                      FtrLink('Sign In', onTap: () => Navigator.of(context).popUntil((r) => r.isFirst)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
