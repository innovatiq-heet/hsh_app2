import 'package:flutter/material.dart';

/// Shared visual tokens matching the Hostel Phonebook executive navy-and-slate theme.
class PhonebookTheme {
  PhonebookTheme._();

  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color blue = Color(0xFF0284C7);
  static const Color blueSoft = Color(0xFFE0F2FE);
  static const Color ink = Color(0xFF0F172A);
  static const Color slate = Color(0xFF475569);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color amber = Color(0xFFD97706);
  static const Color amberBright = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFEF3C7);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFFECFDF5);
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color purple = Color(0xFF9333EA);
  static const Color purpleSoft = Color(0xFFF3E8FF);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF03192E),
      Color(0xFF032B4F),
      Color(0xFF025A8D),
      Color(0xFF0369A1),
    ],
    stops: [0.0, 0.38, 0.75, 1.0],
  );
}

/// Frosted status pill used inside [PhonebookHeaderDelegate].
class PhonebookHeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const PhonebookHeaderPill({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular translucent button used inside [PhonebookHeaderDelegate].
class PhonebookHeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget? child;

  const PhonebookHeaderCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            alignment: Alignment.center,
            child: child ?? Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Pinned navy-to-ocean collapsible sliver header matching `PhonebookScreen`.
class PhonebookHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String overline;
  final String title;
  final String? subtitle;
  final double topPadding;
  final IconData leadingIcon;
  final String leadingTooltip;
  final VoidCallback onLeadingTap;
  final bool showLeading;
  final Widget? trailing;
  final Widget? pills;

  PhonebookHeaderDelegate({
    required this.overline,
    required this.title,
    this.subtitle,
    required this.topPadding,
    this.leadingIcon = Icons.arrow_back_rounded,
    this.leadingTooltip = 'Back',
    required this.onLeadingTap,
    this.showLeading = true,
    this.trailing,
    this.pills,
  });

  @override
  double get minExtent => topPadding + 60.0;

  @override
  double get maxExtent {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    if (pills != null) return topPadding + (hasSubtitle ? 190.0 : 166.0);
    if (subtitle != null && subtitle!.isNotEmpty) return topPadding + 150.0;
    return topPadding + 136.0;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final progress = (shrinkOffset / range).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular((28.0 * (1.0 - progress)).clamp(0.0, 28.0));

    return Container(
      decoration: BoxDecoration(
        gradient: PhonebookTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        boxShadow: progress > 0.25
            ? [
                BoxShadow(
                  color: const Color(0xFF03192E).withValues(alpha: 0.22 * progress),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: CustomPaint(painter: _PhonebookOrbPainter())),
            Positioned(
              top: topPadding + 6,
              left: 14,
              right: 14,
              height: 48,
              child: Row(
                children: [
                  if (showLeading) ...[
                    PhonebookHeaderCircleButton(
                      icon: leadingIcon,
                      tooltip: leadingTooltip,
                      onTap: onLeadingTap,
                    ),
                    const SizedBox(width: 12),
                  ] else
                    const SizedBox(width: 6),
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Opacity(
                opacity: expandedOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      overline.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: PhonebookTheme.amberBright,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                    if (pills != null) ...[
                      const SizedBox(height: 10),
                      pills!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _PhonebookOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.86, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Elevated white card matching `PhonebookScreen` surfaces.
class PhonebookCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const PhonebookCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhonebookTheme.border),
        boxShadow: [
          BoxShadow(
            color: PhonebookTheme.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}

/// Compact metric count card with tinted icon badge and bold value.
class PhonebookCountCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool highlighted;
  final VoidCallback? onTap;

  const PhonebookCountCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? color.withValues(alpha: 0.6) : PhonebookTheme.border,
              width: highlighted ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (highlighted ? color : PhonebookTheme.ink).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 15, color: color),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PhonebookTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search bar + optional companion filter button matching `PhonebookScreen`.
class PhonebookSearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool hasQuery;
  final VoidCallback onClear;
  final VoidCallback? onFilterTap;
  final int activeFilterCount;

  const PhonebookSearchFilterBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.hasQuery,
    required this.onClear,
    this.onFilterTap,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PhonebookTheme.border),
              boxShadow: [
                BoxShadow(
                  color: PhonebookTheme.ink.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                color: PhonebookTheme.ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: PhonebookTheme.blue,
                  size: 22,
                ),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: PhonebookTheme.muted,
                        ),
                        onPressed: onClear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: 8),
          Material(
            color: activeFilterCount > 0 ? PhonebookTheme.blue : Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: activeFilterCount > 0 ? 3 : 1,
            shadowColor: activeFilterCount > 0
                ? PhonebookTheme.blue.withValues(alpha: 0.3)
                : Colors.black12,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onFilterTap,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: activeFilterCount > 0 ? PhonebookTheme.blue : PhonebookTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: activeFilterCount > 0 ? Colors.white : PhonebookTheme.blue,
                    ),
                    if (activeFilterCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$activeFilterCount',
                          style: const TextStyle(
                            color: PhonebookTheme.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Animated rounded-20 pill tab matching `PhonebookScreen`'s group filter chips.
class PhonebookPillTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const PhonebookPillTab({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    this.color = PhonebookTheme.blue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? color : PhonebookTheme.border,
                width: 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: selected ? Colors.white : color),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : PhonebookTheme.slate,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header with amber bar matching `PhonebookScreen`.
class PhonebookSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const PhonebookSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 3.5,
            decoration: BoxDecoration(
              color: PhonebookTheme.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: PhonebookTheme.slate,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) ...[
                      Icon(actionIcon, size: 15, color: PhonebookTheme.blue),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PhonebookTheme.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Outlined text field look used on Phonebook-styled forms: pale fill, slate
/// border, blue focus ring. Pass it to [TextField.decoration].
InputDecoration phonebookInputDecoration({
  String? label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool alignLabelWithHint = false,
  EdgeInsetsGeometry? contentPadding,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: alignLabelWithHint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: contentPadding,
    filled: true,
    fillColor: PhonebookTheme.bg,
    labelStyle: const TextStyle(color: PhonebookTheme.muted),
    floatingLabelStyle: const TextStyle(color: PhonebookTheme.blue, fontWeight: FontWeight.w600),
    hintStyle: TextStyle(color: PhonebookTheme.muted.withValues(alpha: 0.7)),
    counterStyle: const TextStyle(color: PhonebookTheme.muted, fontSize: 11),
    border: border(PhonebookTheme.border),
    enabledBorder: border(PhonebookTheme.border),
    focusedBorder: border(PhonebookTheme.blue, 1.6),
  );
}

/// A choice chip in its own colour: soft tint with a coloured label, solid
/// with white text and a tick when chosen.
class PhonebookTintChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const PhonebookTintChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = PhonebookTheme.blue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected || icon != null) ...[
                Icon(selected ? Icons.check_rounded : icon, size: 15, color: selected ? Colors.white : color),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 12.5,
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
