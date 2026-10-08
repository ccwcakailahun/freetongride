import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import 'otp_screen.dart';

/// Canvas 13 — Create your account.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agree = true;
  bool _busy = false;

  Future<void> _create() async {
    if (!_agree) {
      showError(context, ApiException('Please agree to the Terms of Service and Privacy Policy.'));
      return;
    }
    if (_name.text.trim().length < 2) {
      showError(context, ApiException('Enter your full name.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final sent = await context.read<Session>().api.register(
            fullName: _name.text.trim(),
            phone: _phone.text,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            password: _password.text,
          );
      if (mounted) go(context, OtpScreen(sent: sent));
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
          child: FtrFitScreen(
            padding: EdgeInsets.zero,
            children: [
              Stack(children: [
                const Padding(padding: EdgeInsets.only(top: 92), child: FtrHero('hero_create_account.png', height: 190)),
                const Positioned(top: 12, left: 0, right: 0, child: Center(child: FtrBrandHeader(size: FtrBrandSize.medium))),
                Positioned(top: 4, left: 4, child: FtrBackButton(onTap: () => Navigator.pop(context))),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Create your '),
                          TextSpan(text: 'account', style: FtrText.display.copyWith(color: FtrColors.blue)),
                        ]),
                        textAlign: TextAlign.center,
                        style: FtrText.display.copyWith(fontSize: 34),
                      ),
                      const SizedBox(height: 8),
                      Text('Join FreeTongRide and start moving around Freetown with ease.',
                          textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5, color: FtrColors.muted)),
                      const SizedBox(height: 22),
                      FtrIconField(
                        icon: Icons.person_outline_rounded,
                        label: 'Full name',
                        hint: 'e.g. Mariama Conteh',
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: 14),
                      _PhoneCard(controller: _phone),
                      const SizedBox(height: 14),
                      FtrIconField(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email address',
                        hint: 'e.g. mariama@email.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      FtrIconField(
                        icon: Icons.lock_outline_rounded,
                        label: 'Password',
                        hint: '8+ characters, a number and a capital',
                        controller: _password,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _create(),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Checkbox(value: _agree, activeColor: FtrColors.blue, onChanged: (v) => setState(() => _agree = v ?? false)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(text: 'Terms of Service', style: FtrText.link.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                              const TextSpan(text: ' and '),
                              TextSpan(text: 'Privacy Policy', style: FtrText.link.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                            ]),
                            style: FtrText.body.copyWith(fontSize: 15),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      FtrPrimaryButton(label: 'Create Account', loading: _busy, onPressed: _create),
                      const SizedBox(height: 18),
                      Row(children: [
                        const Expanded(child: Divider(indent: 30)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(children: [
                            Text('Already have an account?', style: FtrText.bodyMuted.copyWith(fontSize: 15)),
                            FtrLink('Sign In', fontSize: 15, onTap: () => Navigator.pop(context)),
                          ]),
                        ),
                        const Expanded(child: Divider(endIndent: 30)),
                      ]),
                      const SizedBox(height: 16),
                      const Row(children: [
                        Expanded(child: _TrustBadge(icon: Icons.bolt_rounded, label: 'Trusted\nlocal drivers', color: FtrColors.green)),
                        SizedBox(width: 10),
                        Expanded(child: _TrustBadge(icon: Icons.verified_user_rounded, label: 'Secure\npayments', color: FtrColors.blue)),
                        SizedBox(width: 10),
                        Expanded(child: _TrustBadge(icon: Icons.location_on_rounded, label: 'Live trip\ntracking', color: FtrColors.purple)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone card: icon tile, flag + +232, divider, label over input.
class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FtrColors.border, width: 1.2),
        boxShadow: ftrSoftShadow,
      ),
      child: Row(children: [
        const FtrIconTile(Icons.call_outlined, size: 54),
        const SizedBox(width: 14),
        const FtrCountryCode(roundFlag: true),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Phone number', style: FtrText.label.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: phoneFormatters,
              style: FtrText.body.copyWith(color: FtrColors.ink, fontSize: 15.5),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'e.g. 76 123 456',
                hintStyle: FtrText.body.copyWith(color: FtrColors.faint, fontSize: 15),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: FtrText.label.copyWith(fontSize: 14, height: 1.25)),
      ]),
    );
  }
}
