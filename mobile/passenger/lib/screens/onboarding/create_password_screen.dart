import 'package:flutter/material.dart';
import 'package:ftr_core/ftr_core.dart';
import 'package:provider/provider.dart';

/// Canvas 16 — Secure your account. Sets a new password after the reset code.
class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key, required this.phone, required this.code});
  final String phone;
  final String code;

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  bool get _len => _password.text.length >= 8;
  bool get _digit => _password.text.contains(RegExp(r'\d'));
  bool get _upper => _password.text.contains(RegExp(r'[A-Z]'));

  Future<void> _save() async {
    if (!(_len && _digit && _upper)) {
      showError(context, ApiException('Your password must meet all three rules.'));
      return;
    }
    if (_password.text != _confirm.text) {
      showError(context, ApiException('The two passwords do not match.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<Session>().api.resetPassword(widget.phone, widget.code, _password.text);
      if (!mounted) return;
      showToast(context, 'Password saved. Sign in with your new password.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _rule(String text, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: ok ? FtrColors.greenSoft : const Color(0xFFEFF2F7), shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: ok ? FtrColors.green : FtrColors.faint, size: 22),
          ),
          const SizedBox(width: 14),
          Text(text, style: FtrText.body.copyWith(fontSize: 15.5, color: ok ? FtrColors.ink : FtrColors.body)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FtrBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            children: [
              const Align(alignment: Alignment.centerLeft, child: FtrBackButton(label: 'Back')),
              const Center(child: FtrBrandHeader(size: FtrBrandSize.medium)),
              const SizedBox(height: 10),
              SizedBox(height: 150, child: ftrImage('illus_password.png', fit: BoxFit.contain)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Secure', style: FtrText.display.copyWith(color: FtrColors.blue)),
                  const TextSpan(text: ' your account'),
                ]),
                textAlign: TextAlign.center,
                style: FtrText.display.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 8),
              Text('Create a strong password to protect your FreeTongRide account.',
                  textAlign: TextAlign.center, style: FtrText.body.copyWith(fontSize: 16.5, color: FtrColors.muted)),
              const SizedBox(height: 22),
              Text('Password', style: FtrText.title.copyWith(fontSize: 17)),
              const SizedBox(height: 10),
              FtrPlainField(
                hint: 'Create a password',
                icon: Icons.lock_outline_rounded,
                controller: _password,
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Text('Confirm password', style: FtrText.title.copyWith(fontSize: 17)),
              const SizedBox(height: 10),
              FtrPlainField(hint: 'Confirm your password', icon: Icons.lock_outline_rounded, controller: _confirm, obscure: true, onSubmitted: (_) => _save()),
              const SizedBox(height: 18),
              FtrCard(
                color: const Color(0xFFF4F7FC),
                border: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your password must include:', style: FtrText.title.copyWith(fontSize: 16)),
                  const SizedBox(height: 8),
                  _rule('At least 8 characters', _len),
                  _rule('One number (e.g. 0-9)', _digit),
                  _rule('One uppercase letter (e.g. A-Z)', _upper),
                ]),
              ),
              const SizedBox(height: 14),
              FtrCard(
                child: Row(children: [
                  const FtrIconTile(Icons.verified_user_rounded, size: 60, circle: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('We keep your account secure', style: FtrText.title.copyWith(fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('Your information is encrypted and kept private and safe.', style: FtrText.bodyMuted),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              FtrPrimaryButton(label: 'Save Password', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
