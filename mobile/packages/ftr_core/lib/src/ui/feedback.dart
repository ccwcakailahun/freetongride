import 'package:flutter/material.dart';

import '../data/api.dart';
import 'buttons.dart';
import 'theme.dart';

void showError(BuildContext context, Object error) {
  final msg = error is ApiException ? error.message : 'Something went wrong. Please try again.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF9EA1)),
        const SizedBox(width: 12),
        Expanded(child: Text(msg)),
      ]),
    ));
}

void showToast(BuildContext context, String msg, {IconData icon = Icons.check_circle_rounded}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: FtrColors.greenBright),
        const SizedBox(width: 12),
        Expanded(child: Text(msg)),
      ]),
    ));
}

/// In-app confirmation sheet. Returns true when the person confirms.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Go back',
  bool destructive = false,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: FtrText.h2),
          const SizedBox(height: 8),
          Text(message, style: FtrText.body),
          const SizedBox(height: 22),
          FtrPrimaryButton(
            label: confirmLabel,
            showArrow: false,
            gradient: destructive ? const LinearGradient(colors: [Color(0xFFF0575C), FtrColors.red]) : FtrColors.primaryGradient,
            onPressed: () => Navigator.pop(ctx, true),
          ),
          const SizedBox(height: 10),
          FtrOutlineButton(label: cancelLabel, onPressed: () => Navigator.pop(ctx, false)),
        ]),
      ),
    ),
  );
  return ok ?? false;
}

/// Friendly empty state with an icon, title and hint.
class FtrEmptyState extends StatelessWidget {
  const FtrEmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: FtrColors.blueSoft, shape: BoxShape.circle),
            child: Icon(icon, color: FtrColors.blue, size: 40),
          ),
          const SizedBox(height: 18),
          Text(title, style: FtrText.h3, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: FtrText.bodyMuted, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      );
}
