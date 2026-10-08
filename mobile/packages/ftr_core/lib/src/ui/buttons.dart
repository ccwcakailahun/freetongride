import 'package:flutter/material.dart';

import 'theme.dart';

/// Blue gradient pill with the label centred and an arrow on the right ("Create Account →").
class FtrPrimaryButton extends StatelessWidget {
  const FtrPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = true,
    this.icon,
    this.gradient = FtrColors.primaryGradient,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final IconData? icon;
  final Gradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled || loading ? 1 : 0.55,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: enabled ? [BoxShadow(color: gradient.colors.last.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))] : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(height / 2),
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      child: Center(
                        child: loading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 10)],
                                  Flexible(child: Text(label, style: FtrText.button, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      child: showArrow && !loading ? const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24) : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill with a thin border and blue label ("Not now", "Skip for now").
class FtrOutlineButton extends StatelessWidget {
  const FtrOutlineButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 58, this.filled = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  /// Light blue fill instead of white, as used for "Edit Profile" and "Book again".
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? FtrColors.blueSoft : Colors.white,
          side: BorderSide(color: filled ? FtrColors.blueSoft : FtrColors.border, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
          foregroundColor: FtrColors.blue,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 22, color: FtrColors.blue), const SizedBox(width: 10)],
            Text(label, style: FtrText.link.copyWith(fontSize: 17)),
          ],
        ),
      ),
    );
  }
}

/// Compact rounded button used inside cards ("View receipt", "Book again", "Add funds").
class FtrChipButton extends StatelessWidget {
  const FtrChipButton({super.key, required this.label, required this.onPressed, this.icon, this.primary = false, this.height = 48, this.color});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? (color ?? FtrColors.blue) : Colors.white;
    final fg = primary ? Colors.white : (color ?? FtrColors.blue);
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2.6),
          side: primary ? BorderSide.none : const BorderSide(color: FtrColors.border, width: 1.3),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2.6),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 21, color: fg), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: FtrText.label.copyWith(color: fg, fontSize: 15))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text link like "Use email instead" / "Resend code".
class FtrLink extends StatelessWidget {
  const FtrLink(this.text, {super.key, required this.onTap, this.underline = false, this.fontSize = 16});
  final String text;
  final VoidCallback? onTap;
  final bool underline;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: FtrText.link.copyWith(
            fontSize: fontSize,
            color: onTap == null ? FtrColors.faint : FtrColors.blue,
            decoration: underline ? TextDecoration.underline : null,
            decorationColor: FtrColors.blue,
          ),
        ),
      ),
    );
  }
}
