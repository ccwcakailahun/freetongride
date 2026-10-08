import 'package:flutter/material.dart';

import 'theme.dart';

class FtrNavItem {
  const FtrNavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Home · Activity · Wallet · Account, with a short blue bar under the active tab.
class FtrBottomNav extends StatelessWidget {
  const FtrBottomNav({super.key, required this.items, required this.index, required this.onChanged, this.accent = FtrColors.blue});
  final List<FtrNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x141A3C8C), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == index;
              final item = items[i];
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: item.label,
                  child: InkResponse(
                    onTap: () => onChanged(i),
                    radius: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(active ? item.activeIcon : item.icon, size: 30, color: active ? accent : FtrColors.muted),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: FtrText.small.copyWith(
                                fontSize: 14, color: active ? accent : FtrColors.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: active ? 44 : 0,
                          height: 4,
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
