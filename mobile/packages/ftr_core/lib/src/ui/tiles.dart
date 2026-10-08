import 'package:flutter/material.dart';

import 'format.dart';
import 'fields.dart';
import 'theme.dart';

/// White rounded card with a hairline border and soft shadow.
class FtrCard extends StatelessWidget {
  const FtrCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white, this.radius = 22, this.onTap, this.border = true});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: FtrColors.border.withValues(alpha: 0.8)) : null,
        boxShadow: ftrSoftShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Tinted row with an icon tile, title, subtitle and optional chevron
/// (Location benefits, Notification types, Account menu).
class FtrFeatureTile extends StatelessWidget {
  const FtrFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = FtrColors.blue,
    this.tint,
    this.onTap,
    this.chevron = false,
    this.tinted = true,
    this.iconSize = 58,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Color? tint;
  final VoidCallback? onTap;
  final bool chevron;
  final bool tinted;
  final double iconSize;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final soft = tint ?? color.withValues(alpha: 0.12);
    final wash = color.withValues(alpha: 0.055);
    return Container(
      decoration: BoxDecoration(
        color: tinted ? wash : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: tinted ? null : Border.all(color: FtrColors.border.withValues(alpha: 0.8)),
        boxShadow: tinted ? null : ftrSoftShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FtrIconTile(icon, color: color, background: soft, size: iconSize, circle: false),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: FtrText.title.copyWith(fontSize: 16.5, color: titleColor)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: FtrText.bodyMuted.copyWith(fontSize: 14.5)),
                      ],
                    ],
                  ),
                ),
                if (chevron) const Icon(Icons.chevron_right_rounded, color: FtrColors.muted, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Green reassurance card ("Your security matters", "Your safety comes first").
class FtrSafetyBanner extends StatelessWidget {
  const FtrSafetyBanner({super.key, required this.title, required this.message, this.icon = Icons.verified_user_rounded, this.color = FtrColors.green, this.onTap, this.compact = false});
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Row(
            children: [
              Container(
                width: compact ? 56 : 76,
                height: compact ? 56 : 76,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: compact ? 34 : 42),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: FtrText.title.copyWith(fontSize: 17, color: compact ? color : FtrColors.ink)),
                  const SizedBox(height: 4),
                  Text(message, style: FtrText.bodyMuted.copyWith(fontSize: 14.5, color: FtrColors.body)),
                ]),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: color, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Payment Methods          Manage >"
class FtrSectionHeader extends StatelessWidget {
  const FtrSectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: FtrText.h3.copyWith(fontSize: 19))),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                Text(action!, style: FtrText.link.copyWith(fontSize: 15)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, color: FtrColors.blue, size: 22),
              ]),
            ),
          ),
      ],
    );
  }
}

/// Status pill: Completed (green), Cancelled (red), Upcoming (blue).
class FtrStatusPill extends StatelessWidget {
  const FtrStatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  factory FtrStatusPill.completed() => const FtrStatusPill(label: 'Completed', color: FtrColors.green, icon: Icons.check_circle_rounded);
  factory FtrStatusPill.cancelled() => const FtrStatusPill(label: 'Cancelled', color: FtrColors.red, icon: Icons.cancel_rounded);
  factory FtrStatusPill.paid() => const FtrStatusPill(label: 'Paid', color: FtrColors.green);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 10 : 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
        Text(label, style: FtrText.small.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 13.5)),
      ]),
    );
  }
}

/// Round avatar: network photo when available, otherwise initials on a brand gradient.
class FtrAvatar extends StatelessWidget {
  const FtrAvatar({super.key, required this.name, this.photoUrl, this.size = 64, this.online = false, this.ring = true, this.badge});
  final String name;
  final String? photoUrl;
  final double size;
  final bool online;
  final bool ring;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(gradient: FtrColors.brandGradient),
      alignment: Alignment.center,
      child: Text(initials(name), style: FtrText.h2.copyWith(color: Colors.white, fontSize: size * 0.34)),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(ring ? size * 0.045 : 0),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: ring ? ftrSoftShadow : null),
            child: ClipOval(
              child: photoUrl == null || photoUrl!.isEmpty
                  ? fallback
                  : Image.network(photoUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
            ),
          ),
          if (online)
            Positioned(
              right: size * 0.02,
              bottom: size * 0.04,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(color: FtrColors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
              ),
            ),
          if (badge != null) Positioned(right: -size * 0.04, bottom: -size * 0.02, child: badge!),
        ],
      ),
    );
  }
}

/// Small camera badge used on avatars ("change photo").
class FtrCameraBadge extends StatelessWidget {
  const FtrCameraBadge({super.key, this.color = FtrColors.blue, this.size = 40});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: size * 0.48),
      );
}

class FtrRating extends StatelessWidget {
  const FtrRating({super.key, required this.rating, this.count, this.size = 15});
  final double rating;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_rounded, color: FtrColors.star, size: size + 5),
        const SizedBox(width: 3),
        Text(rating.toStringAsFixed(1), style: FtrText.label.copyWith(fontSize: size)),
        if (count != null) Text(' ($count rides)', style: FtrText.bodyMuted.copyWith(fontSize: size)),
      ]);
}

/// Two-dot route summary: green pickup, blue drop-off joined by a line.
class FtrRouteSummary extends StatelessWidget {
  const FtrRouteSummary({super.key, required this.from, required this.to, this.fromCaption, this.toCaption, this.fromLabel, this.toLabel, this.dense = false});
  final String from;
  final String to;
  final String? fromLabel;
  final String? toLabel;
  final String? fromCaption;
  final String? toCaption;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = dense ? FtrText.title.copyWith(fontSize: 16.5) : FtrText.title.copyWith(fontSize: 17);
    Widget line(Color c, String? label, String text, String? caption, {required bool first}) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                if (!first) Container(width: 2, height: 6, color: FtrColors.green.withValues(alpha: 0.4)),
                Container(
                  width: 18,
                  height: 18,
                  margin: EdgeInsets.only(top: first ? 2 : 0),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 5)),
                ),
                if (first) Container(width: 2, height: dense ? 16 : 30, color: FtrColors.green.withValues(alpha: 0.4)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (label != null) Text(label, style: FtrText.small),
                Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (caption != null) Text(caption, style: FtrText.small),
              ]),
            ),
          ],
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line(FtrColors.green, fromLabel, from, fromCaption, first: true),
      line(FtrColors.blue, toLabel, to, toCaption, first: false),
    ]);
  }
}
