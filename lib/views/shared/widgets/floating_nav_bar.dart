import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_text_styles.dart';
import 'glass_container.dart';

class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Floating frosted pill navigation bar with a gradient indicator that
/// springs between tabs. Pair with `Scaffold(extendBody: true)` so content
/// scrolls underneath the frosted surface.
class FloatingNavBar extends StatelessWidget {
  static const double barHeight = 70;

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(28),
          blur: 22,
          tint: AppColors.deepSlate.withValues(alpha: 0.78),
          borderColor: Colors.white.withValues(alpha: 0.08),
          shadows: AppColors.tintedShadow(AppColors.deepSlate, 0.28),
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: barHeight - 12,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / items.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutBack,
                      left: itemWidth * currentIndex,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.indigo, AppColors.primaryLight],
                          ),
                          boxShadow: AppColors.glow(AppColors.primaryLight, 0.55),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (int i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: items[i],
                              selected: i == currentIndex,
                              onTap: () {
                                if (i == currentIndex) return;
                                HapticFeedback.selectionClick();
                                onChanged(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.55);
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                key: ValueKey(selected),
                color: color,
                size: 23,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.fade),
            ),
          ],
        ),
      ),
    );
  }
}
