import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';
import '../../../constants/app_text_styles.dart';
import 'app_card.dart';
import 'fade_slide_in.dart';
import 'icon_badge.dart';

/// Card whose body expands/collapses with a springy size animation, a
/// rotating chevron, and a content cross-fade.
class ExpandableSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget child;
  final bool initiallyExpanded;

  const ExpandableSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.color = AppColors.primary,
    this.initiallyExpanded = false,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.gapLg),
              child: Row(
                children: [
                  IconBadge(icon: widget.icon, color: widget.color, size: 40),
                  const SizedBox(width: AppDimens.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: AppTextStyles.subtitle),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!, style: AppTextStyles.bodySm),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 460),
            reverseDuration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            alignment: Alignment.topCenter,
            child: _expanded
                ? FadeSlideIn(
                    offset: 10,
                    duration: const Duration(milliseconds: 380),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.gapLg,
                        0,
                        AppDimens.gapLg,
                        AppDimens.gapSm,
                      ),
                      child: widget.child,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
