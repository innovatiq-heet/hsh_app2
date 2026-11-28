import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import 'empty_state.dart';
import 'phonebook_style_widgets.dart';
import 'skeleton_loader.dart';

/// One picked item, shown as a removable chip on a [PickerScaffold].
class PickerChip {
  final String label;
  final VoidCallback onRemove;

  const PickerChip({required this.label, required this.onRemove});
}

/// The page behind every "pick several" screen: collapsing header with the
/// selected count, search bar, optional filters, chips for the picks, the
/// results and a pinned Done button. Picks apply at once, so Done and Back
/// both keep them.
class PickerScaffold extends StatelessWidget {
  final String overline;
  final String title;

  /// What is picked, e.g. "student" (an "s" is added for more than one).
  final String noun;
  final TextEditingController search;
  final String searchHint;
  final bool hasQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;

  /// Adds a filter button beside the search bar.
  final VoidCallback? onFilterTap;
  final int activeFilterCount;

  /// Shown under the search bar.
  final Widget? filters;

  /// Called for a sideways swipe on the page: 1 towards the next tab (finger
  /// moving left), -1 towards the previous one. A horizontally scrolling child,
  /// such as the chips, keeps its own swipes.
  final ValueChanged<int>? onSwipe;

  /// The picks, newest or most relevant first. Must read an observable.
  final List<PickerChip> Function() selected;
  final VoidCallback onClearSelection;

  /// The results as a sliver. Must read an observable.
  final Widget Function() results;

  const PickerScaffold({
    super.key,
    required this.overline,
    required this.title,
    required this.noun,
    required this.search,
    required this.searchHint,
    required this.hasQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.selected,
    required this.onClearSelection,
    required this.results,
    this.filters,
    this.onFilterTap,
    this.activeFilterCount = 0,
    this.onSwipe,
  });

  static const _resultsPadding = EdgeInsets.fromLTRB(
    AppDimens.screenPadding,
    14,
    AppDimens.screenPadding,
    AppDimens.gapXl,
  );

  /// Placeholder rows while the first load runs.
  static Widget loadingSliver() => listSliver(
        itemCount: 7,
        itemBuilder: (_, _) => SkeletonLoader(
          height: 54,
          width: double.infinity,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
      );

  /// An empty or error state filling the rest of the page.
  static Widget messageSliver(EmptyState state) => SliverFillRemaining(hasScrollBody: false, child: state);

  /// The result cards.
  static Widget listSliver({required int itemCount, required IndexedWidgetBuilder itemBuilder}) {
    return SliverPadding(
      padding: _resultsPadding,
      sliver: SliverList.separated(
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: itemBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // With the keyboard up, drop the extras so the results stay visible.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final topPadding = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        bottomNavigationBar: typing ? null : _DoneBar(noun: noun, selected: selected),
        body: _SwipeDetector(
          onSwipe: onSwipe,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: PhonebookTheme.blue,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PhonebookHeaderDelegate(
                    overline: overline,
                    title: title,
                    topPadding: topPadding,
                    onLeadingTap: () => Navigator.of(context).maybePop(),
                    pills: Obx(
                      () => PhonebookHeaderPill(
                        icon: Icons.check_circle_rounded,
                        label: '${selected().length} selected',
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.screenPadding,
                      AppDimens.gapLg,
                      AppDimens.screenPadding,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PhonebookSearchFilterBar(
                          controller: search,
                          hintText: searchHint,
                          onChanged: onSearchChanged,
                          hasQuery: hasQuery,
                          onClear: onClearSearch,
                          onFilterTap: onFilterTap,
                          activeFilterCount: activeFilterCount,
                        ),
                        ?filters,
                        if (!typing)
                          Obx(() {
                            final chips = selected();
                            if (chips.isEmpty) return const SizedBox.shrink();
                            return _ChipStrip(chips: chips, onClear: onClearSelection);
                          }),
                      ],
                    ),
                  ),
                ),
                Obx(results),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Turns a sideways drag or flick into [onSwipe].
class _SwipeDetector extends StatefulWidget {
  final ValueChanged<int>? onSwipe;
  final Widget child;

  const _SwipeDetector({required this.onSwipe, required this.child});

  @override
  State<_SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<_SwipeDetector> {
  /// Slower swipes need to travel this far; quicker ones this fast.
  static const _minDistance = 70.0;
  static const _minVelocity = 300.0;

  double _distance = 0;

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final moved = velocity.abs() >= _minVelocity ? velocity : (_distance.abs() >= _minDistance ? _distance : 0.0);
    if (moved != 0) widget.onSwipe?.call(moved < 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onSwipe != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: enabled ? (_) => _distance = 0 : null,
      onHorizontalDragUpdate: enabled ? (d) => _distance += d.primaryDelta ?? 0 : null,
      onHorizontalDragEnd: enabled ? _end : null,
      child: widget.child,
    );
  }
}

/// A result card: an icon or initials (a tick once picked), a name and a
/// small badge.
class PickerTile extends StatelessWidget {
  final String title;
  final Widget leading;
  final Color tone;
  final Color toneSoft;
  final IconData badgeIcon;
  final String badgeLabel;
  final Color? badgeTextColor;
  final bool selected;
  final VoidCallback onTap;

  const PickerTile({
    super.key,
    required this.title,
    required this.leading,
    required this.tone,
    required this.toneSoft,
    required this.badgeIcon,
    required this.badgeLabel,
    this.badgeTextColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F9FF) : Colors.white,
          borderRadius: radius,
          border: Border.all(color: selected ? PhonebookTheme.blue : PhonebookTheme.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: PhonebookTheme.ink.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? PhonebookTheme.blue : toneSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : leading,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(color: PhonebookTheme.ink, fontSize: 13.5, height: 1.25),
                        ),
                        if (badgeLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: toneSoft,
                              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 11, color: tone),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    badgeLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption.copyWith(color: badgeTextColor ?? tone, fontSize: 10.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    size: 23,
                    color: selected ? PhonebookTheme.blue : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The picks as removable chips, with Clear.
class _ChipStrip extends StatelessWidget {
  final List<PickerChip> chips;
  final VoidCallback onClear;

  const _ChipStrip({required this.chips, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                // Takes sideways drags even when the chips fit, so sliding
                // them never changes the tab.
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppDimens.gapSm),
                itemBuilder: (_, i) => Center(
                  child: InputChip(
                    label: Text(chips[i].label),
                    labelStyle: AppTextStyles.label.copyWith(color: PhonebookTheme.ink, fontSize: 12),
                    backgroundColor: PhonebookTheme.blueSoft,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: chips[i].onRemove,
                    deleteIcon: const Icon(Icons.close_rounded, size: 15),
                    deleteIconColor: PhonebookTheme.blue,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: PhonebookTheme.red,
                textStyle: AppTextStyles.label,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned bottom button; shows how many are picked.
class _DoneBar extends StatelessWidget {
  final String noun;
  final List<PickerChip> Function() selected;

  const _DoneBar({required this.noun, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: PhonebookTheme.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: PhonebookTheme.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Obx(() {
                final n = selected().length;
                return Text(
                  n == 0 ? 'Done' : 'Done · $n $noun${n == 1 ? '' : 's'}',
                  style: AppTextStyles.button,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
