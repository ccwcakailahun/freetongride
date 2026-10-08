import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import 'create_account_screen.dart';
import 'flow.dart';
import 'verify_phone_screen.dart';

/// Canvas 12 — Welcome back.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _busy = false;

  Future<void> _signIn() async {
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      showError(context, ApiException('Enter your phone number and password.'));
      return;
    }
    setState(() => _busy = true);
    final session = context.read<Session>();
    try {
      final r = await session.api.login(_phone.text, _password.text);
      await session.signIn(r);
      if (mounted) await continueAfterSignIn(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.needsVerification) {
        go(context, VerifyPhoneScreen(initialPhone: _phone.text));
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
        child: Stack(
          children: [
            Positioned(left: 0, right: 0, bottom: 0, child: _BottomWave()),
            SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 18),
                  const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
                  const FtrHero('hero_signin.png', height: 250),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'Welcome '),
                              TextSpan(text: 'back', style: FtrText.display.copyWith(color: FtrColors.blue)),
                            ]),
                            textAlign: TextAlign.center,
                            style: FtrText.display.copyWith(fontSize: 38),
                          ),
                          const SizedBox(height: 10),
                          Text('Sign in to continue booking safe rides across Freetown.',
                              textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5)),
                          const SizedBox(height: 26),
                          FtrPlainField(
                            hint: 'Phone number',
                            prefix: const FtrCountryCode(),
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.telephoneNumberNational],
                            inputFormatters: phoneFormatters,
                          ),
                          const SizedBox(height: 16),
                          FtrPlainField(
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            controller: _password,
                            obscure: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _signIn(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: Checkbox(
                                  value: _remember,
                                  activeColor: FtrColors.blue,
                                  onChanged: (v) => setState(() => _remember = v ?? true),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('Remember me', style: FtrText.label.copyWith(fontSize: 15.5)),
                              const Spacer(),
                              FtrLink('Forgot password?', fontSize: 15.5, onTap: () => go(context, VerifyPhoneScreen(initialPhone: _phone.text, resetPassword: true))),
                            ],
                          ),
                          const SizedBox(height: 18),
                          FtrPrimaryButton(label: 'Sign In', loading: _busy, onPressed: _signIn),
                          const SizedBox(height: 22),
                          Row(children: [
                            const Expanded(child: Divider()),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('or continue with', style: FtrText.bodyMuted)),
                            const Expanded(child: Divider()),
                          ]),
                          const SizedBox(height: 18),
                          _GoogleButton(onTap: () => showToast(context, 'Google sign-in is coming soon. Use your phone number for now.', icon: Icons.info_outline_rounded)),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text("Don't have an account?", style: FtrText.bodyMuted.copyWith(fontSize: 15)),
                              FtrLink('Create a new account', fontSize: 15, onTap: () => go(context, const CreateAccountScreen())),
                            ],
                          ),
                          const SizedBox(height: 70),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: FtrColors.border, width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const _GoogleG(size: 30),
          const SizedBox(width: 18),
          Text('Continue with Google', style: FtrText.title.copyWith(fontSize: 17)),
        ]),
      ),
    );
  }
}

/// Four-colour "G" drawn with arcs so no Google asset is bundled.
class _GoogleG extends StatelessWidget {
  const _GoogleG({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final stroke = s.width * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.14159 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, -230 * deg, -95 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, 35 * deg, -35 * deg, false, p(const Color(0xFF4285F4)));
    canvas.drawLine(Offset(s.width / 2, s.height / 2), Offset(s.width - stroke / 2, s.height / 2), p(const Color(0xFF4285F4))..strokeWidth = stroke * 0.95);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomWave extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          height: 120,
          child: ftrImage('splash_wave.png', width: double.infinity, fit: BoxFit.cover, alignment: Alignment.bottomCenter),
        ),
      );
}
