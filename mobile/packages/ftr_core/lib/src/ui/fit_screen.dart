import 'package:flutter/material.dart';

/// Lays a screen out like the mockups: the whole design fits on the phone at once, with no scrolling.
/// The content is laid out at the phone's width and, on shorter phones, scaled down evenly to fit the height.
/// While the keyboard is open it scrolls instead, so the field being typed in stays reachable.
class FtrFitScreen extends StatelessWidget {
  const FtrFitScreen({super.key, required this.children, this.padding = EdgeInsets.zero, this.crossAxisAlignment = CrossAxisAlignment.stretch});

  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(builder: (context, c) {
      final column = Padding(
        padding: padding,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: crossAxisAlignment, children: children),
      );
      if (keyboardOpen) {
        return SingleChildScrollView(physics: const ClampingScrollPhysics(), child: column);
      }
      return SizedBox(
        width: c.maxWidth,
        height: c.maxHeight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(width: c.maxWidth, child: column),
        ),
      );
    });
  }
}
