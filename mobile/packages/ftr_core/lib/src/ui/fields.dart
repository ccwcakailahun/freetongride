import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Sierra Leone flag: green, white, blue.
class SierraLeoneFlag extends StatelessWidget {
  const SierraLeoneFlag({super.key, this.size = 30, this.round = true});
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final flag = Column(children: [
      Expanded(child: Container(color: const Color(0xFF1EB53A))),
      Expanded(child: Container(color: Colors.white)),
      Expanded(child: Container(color: const Color(0xFF0072C6))),
    ]);
    return Container(
      width: round ? size : size * 1.3,
      height: size,
      decoration: BoxDecoration(
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(4),
        border: Border.all(color: FtrColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: flag,
    );
  }
}

/// Rounded square with a soft tint behind an icon.
class FtrIconTile extends StatelessWidget {
  const FtrIconTile(this.icon, {super.key, this.color = FtrColors.blue, this.background = FtrColors.blueSoft, this.size = 56, this.iconSize, this.circle = false});
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double? iconSize;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.48),
    );
  }
}

BoxDecoration _cardField({bool focused = false, bool error = false}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: error ? FtrColors.red : (focused ? FtrColors.blue.withValues(alpha: 0.55) : FtrColors.border), width: focused ? 1.6 : 1.2),
      boxShadow: ftrSoftShadow,
    );

/// Create Account style: icon tile on the left, label on top, input below.
class FtrIconField extends StatefulWidget {
  const FtrIconField({
    super.key,
    required this.icon,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.autofillHints,
    this.inputFormatters,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.trailing,
    this.readOnly = false,
    this.onTap,
    this.valueStyleBold = false,
    this.errorText,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final Widget? trailing;
  final bool readOnly;
  final VoidCallback? onTap;

  /// Complete Profile style: small grey label over a bold value.
  final bool valueStyleBold;
  final String? errorText;

  @override
  State<FtrIconField> createState() => _FtrIconFieldState();
}

class _FtrIconFieldState extends State<FtrIconField> {
  final _focus = FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bold = widget.valueStyleBold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onTap ?? () => _focus.requestFocus(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: _cardField(focused: _focus.hasFocus, error: widget.errorText != null),
            child: Row(
              children: [
                FtrIconTile(widget.icon, size: 54),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label,
                          style: bold ? FtrText.small.copyWith(fontSize: 13.5) : FtrText.label.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        readOnly: widget.readOnly,
                        onTap: widget.onTap,
                        obscureText: _hidden,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        autofillHints: widget.autofillHints,
                        inputFormatters: widget.inputFormatters,
                        textCapitalization: widget.textCapitalization,
                        onSubmitted: widget.onSubmitted,
                        style: bold
                            ? FtrText.title.copyWith(fontSize: 17, fontWeight: FontWeight.w600)
                            : FtrText.body.copyWith(color: FtrColors.ink, fontSize: 15.5),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: widget.hint,
                          hintStyle: FtrText.body.copyWith(color: FtrColors.faint, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.obscure)
                  IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: FtrColors.muted, size: 26),
                  )
                else if (widget.trailing != null)
                  widget.trailing!,
              ],
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(widget.errorText!, style: FtrText.small.copyWith(color: FtrColors.red)),
          ),
      ],
    );
  }
}

/// Sign In / Create Password style: single-line rounded field with a leading icon.
class FtrPlainField extends StatefulWidget {
  const FtrPlainField({
    super.key,
    required this.hint,
    this.icon,
    this.prefix,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.height = 64,
  });

  final String hint;
  final IconData? icon;
  final Widget? prefix;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final double height;

  @override
  State<FtrPlainField> createState() => _FtrPlainFieldState();
}

class _FtrPlainFieldState extends State<FtrPlainField> {
  late bool _hidden = widget.obscure;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: _cardField(focused: _focus.hasFocus).copyWith(borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          if (widget.prefix != null) widget.prefix!,
          if (widget.icon != null) ...[Icon(widget.icon, color: FtrColors.muted, size: 26), const SizedBox(width: 16)],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              inputFormatters: widget.inputFormatters,
              style: FtrText.body.copyWith(color: FtrColors.ink, fontSize: 16.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: FtrText.body.copyWith(color: FtrColors.faint, fontSize: 16.5),
              ),
            ),
          ),
          if (widget.obscure)
            IconButton(
              tooltip: _hidden ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: FtrColors.muted, size: 26),
            ),
        ],
      ),
    );
  }
}

/// "🇸🇱 +232 ⌄ | Phone number" prefix block used by phone fields.
class FtrCountryCode extends StatelessWidget {
  const FtrCountryCode({super.key, this.roundFlag = false, this.withDivider = true});
  final bool roundFlag;
  final bool withDivider;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SierraLeoneFlag(size: roundFlag ? 30 : 24, round: roundFlag),
      const SizedBox(width: 12),
      Text('+232', style: FtrText.title.copyWith(fontSize: 17)),
      const SizedBox(width: 4),
      const Icon(Icons.keyboard_arrow_down_rounded, color: FtrColors.blue, size: 22),
      if (withDivider) ...[
        const SizedBox(width: 12),
        Container(width: 1.2, height: 34, color: FtrColors.border),
        const SizedBox(width: 16),
      ],
    ]);
  }
}

/// Accepts digits and spaces only, max 8 digits (Sierra Leone local number).
final phoneFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
  _MaxDigits(9),
];

class _MaxDigits extends TextInputFormatter {
  _MaxDigits(this.max);
  final int max;
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.text.replaceAll(' ', '').length > max ? oldValue : newValue;
}

/// Six boxes for the verification / pickup code. Paste and SMS autofill go to the hidden field.
class FtrCodeInput extends StatefulWidget {
  const FtrCodeInput({super.key, required this.onCompleted, this.length = 6, this.controller, this.onChanged, this.error = false});
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final int length;
  final TextEditingController? controller;
  final bool error;

  @override
  State<FtrCodeInput> createState() => _FtrCodeInputState();
}

class _FtrCodeInputState extends State<FtrCodeInput> {
  late final TextEditingController _c = widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _c.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              child: TextField(
                controller: _c,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
                onChanged: (v) {
                  widget.onChanged?.call(v);
                  if (v.length == widget.length) widget.onCompleted(v);
                },
              ),
            ),
          ),
          Row(
            children: List.generate(widget.length, (i) {
              final filled = i < text.length;
              final active = _focus.hasFocus && i == text.length.clamp(0, widget.length - 1);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AspectRatio(
                    aspectRatio: 0.86,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.error ? FtrColors.red : (active ? FtrColors.blue : FtrColors.border),
                          width: active ? 1.8 : 1.3,
                        ),
                        boxShadow: ftrSoftShadow,
                      ),
                      alignment: Alignment.center,
                      child: filled
                          ? Text(text[i], style: FtrText.h1.copyWith(fontSize: 26))
                          : Container(width: 16, height: 2, color: FtrColors.faint.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
