import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/forms/form_models.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../../shared/widgets/student_contact_card.dart';
import '../controllers/forms_list_controller.dart';

/// Operator → Forms & Polls, styled to match the Hostel Phonebook theme.
class FormsListScreen extends GetView<FormsListController> {
  const FormsListScreen({super.key});

  Future<void> _edit([HostelForm? form]) async {
    final saved = await Get.toNamed(Routes.operatorFormEditor, arguments: form);
    if (saved == true) controller.load(showLoading: false);
  }

  Future<void> _confirmDelete(BuildContext context, HostelForm form) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Delete "${form.title}" with its ${form.totalResponded} '
          '${form.totalResponded == 1 ? 'response' : 'responses'}? This cannot be undone.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          AppButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            variant: AppButtonVariant.danger,
            expand: false,
            onPressed: () => Navigator.of(d).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) await controller.delete(form);
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Obx(() {
              final activeCount = controller.activeFilterCount;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PhonebookTheme.blueSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: PhonebookTheme.blue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Forms & Polls',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: PhonebookTheme.ink,
                              ),
                            ),
                            Text(
                              'Refine by status, type, and required flag',
                              style: TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                            ),
                          ],
                        ),
                      ),
                      if (activeCount > 0)
                        TextButton(
                          onPressed: controller.resetFilters,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text(
                            'Reset All',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: PhonebookTheme.muted, size: 22),
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: PhonebookTheme.border),
                  _sheetHeader('TYPE', Icons.how_to_vote_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sheetChip(
                        label: 'All Types',
                        selected: controller.kindFilter.value == null,
                        color: PhonebookTheme.blue,
                        onTap: () => controller.kindFilter.value = null,
                      ),
                      _sheetChip(
                        label: 'Polls Only',
                        selected: controller.kindFilter.value == FormKind.poll,
                        color: PhonebookTheme.purple,
                        onTap: () => controller.kindFilter.value = FormKind.poll,
                      ),
                      _sheetChip(
                        label: 'Forms Only',
                        selected: controller.kindFilter.value == FormKind.form,
                        color: PhonebookTheme.blue,
                        onTap: () => controller.kindFilter.value = FormKind.form,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sheetHeader('STATUS', Icons.play_circle_outline_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sheetChip(
                        label: 'All (${controller.forms.length})',
                        selected: controller.filter.value == null,
                        color: PhonebookTheme.blue,
                        onTap: () => controller.filter.value = null,
                      ),
                      _sheetChip(
                        label: 'Active (${controller.countOf(FormStatus.active)})',
                        selected: controller.filter.value == FormStatus.active,
                        color: PhonebookTheme.green,
                        onTap: () => controller.filter.value = FormStatus.active,
                      ),
                      _sheetChip(
                        label: 'Upcoming (${controller.countOf(FormStatus.upcoming)})',
                        selected: controller.filter.value == FormStatus.upcoming,
                        color: PhonebookTheme.blue,
                        onTap: () => controller.filter.value = FormStatus.upcoming,
                      ),
                      _sheetChip(
                        label: 'Paused (${controller.countOf(FormStatus.disabled)})',
                        selected: controller.filter.value == FormStatus.disabled,
                        color: PhonebookTheme.amber,
                        onTap: () => controller.filter.value = FormStatus.disabled,
                      ),
                      _sheetChip(
                        label: 'Ended (${controller.countOf(FormStatus.expired)})',
                        selected: controller.filter.value == FormStatus.expired,
                        color: PhonebookTheme.muted,
                        onTap: () => controller.filter.value = FormStatus.expired,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PhonebookTheme.border),
                    ),
                    child: SwitchListTile(
                      value: controller.onlyMandatory.value,
                      onChanged: (v) => controller.onlyMandatory.value = v,
                      activeThumbColor: PhonebookTheme.red,
                      title: const Text(
                        'Required only',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
                      ),
                      subtitle: const Text(
                        'Show only mandatory forms & polls',
                        style: TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PhonebookTheme.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Show ${controller.visible.length} ${controller.visible.length == 1 ? 'Item' : 'Items'}',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  static Widget _sheetHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 15, color: PhonebookTheme.muted),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: PhonebookTheme.slate,
          letterSpacing: 0.7,
        ),
      ),
    ],
  );

  static Widget _sheetChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) => PhonebookTintChip(label: label, selected: selected, color: color, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          backgroundColor: PhonebookTheme.blue,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New poll or form', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: RefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          color: PhonebookTheme.blue,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: PhonebookHeaderDelegate(
                  overline: 'Hostel office',
                  title: 'Forms & Polls',
                  topPadding: MediaQuery.of(context).padding.top,
                  onLeadingTap: () => Navigator.of(context).maybePop(),
                  trailing: Obx(() {
                    final loading = controller.isLoading.value;
                    return PhonebookHeaderCircleButton(
                      icon: Icons.sync_rounded,
                      tooltip: 'Refresh forms',
                      onTap: loading ? null : () => controller.load(showLoading: false),
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : null,
                    );
                  }),
                  pills: Obx(
                    () => Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        PhonebookHeaderPill(
                          icon: Icons.play_circle_rounded,
                          label: '${controller.countOf(FormStatus.active)} active',
                        ),
                        PhonebookHeaderPill(
                          icon: Icons.assignment_rounded,
                          label: '${controller.forms.length} total',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3 Elevated Count Cards matching Phonebook theme
                      Obx(
                        () => Row(
                          children: [
                            Expanded(
                              child: PhonebookCountCard(
                                value: '${controller.countOf(FormStatus.active)}',
                                label: 'Active',
                                icon: Icons.play_circle_outline_rounded,
                                color: PhonebookTheme.green,
                                bgColor: PhonebookTheme.greenSoft,
                                highlighted: controller.filter.value == FormStatus.active,
                                onTap: () {
                                  controller.filter.value = controller.filter.value == FormStatus.active
                                      ? null
                                      : FormStatus.active;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PhonebookCountCard(
                                value: '${controller.totalResponses}',
                                label: 'Responses',
                                icon: Icons.how_to_vote_outlined,
                                color: PhonebookTheme.blue,
                                bgColor: PhonebookTheme.blueSoft,
                                onTap: controller.resetFilters,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PhonebookCountCard(
                                value:
                                    '${controller.countOf(FormStatus.upcoming) + controller.countOf(FormStatus.disabled)}',
                                label: 'Paused / Soon',
                                icon: Icons.schedule_rounded,
                                color: PhonebookTheme.amber,
                                bgColor: PhonebookTheme.amberSoft,
                                highlighted: controller.filter.value == FormStatus.disabled,
                                onTap: () {
                                  controller.filter.value = controller.filter.value == FormStatus.disabled
                                      ? null
                                      : FormStatus.disabled;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Search bar + Filter button (exact Phonebook style)
                      Obx(
                        () => PhonebookSearchFilterBar(
                          controller: controller.searchController,
                          hintText: 'Search poll or form title...',
                          onChanged: controller.onSearchChanged,
                          hasQuery: controller.search.value.isNotEmpty,
                          onClear: controller.clearSearch,
                          onFilterTap: () => _showFilterBottomSheet(context),
                          activeFilterCount: controller.activeFilterCount,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status pill tabs (exact Phonebook AnimatedContainer style)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Obx(() {
                          final f = controller.filter.value;
                          return Row(
                            children: [
                              PhonebookPillTab(
                                label: 'All (${controller.forms.length})',
                                selected: f == null,
                                color: PhonebookTheme.blue,
                                onTap: () => controller.filter.value = null,
                              ),
                              PhonebookPillTab(
                                label: 'Active (${controller.countOf(FormStatus.active)})',
                                icon: Icons.play_circle_rounded,
                                selected: f == FormStatus.active,
                                color: PhonebookTheme.green,
                                onTap: () => controller.filter.value = FormStatus.active,
                              ),
                              PhonebookPillTab(
                                label: 'Upcoming (${controller.countOf(FormStatus.upcoming)})',
                                icon: Icons.schedule_rounded,
                                selected: f == FormStatus.upcoming,
                                color: PhonebookTheme.blue,
                                onTap: () => controller.filter.value = FormStatus.upcoming,
                              ),
                              PhonebookPillTab(
                                label: 'Paused (${controller.countOf(FormStatus.disabled)})',
                                icon: Icons.pause_circle_rounded,
                                selected: f == FormStatus.disabled,
                                color: PhonebookTheme.amber,
                                onTap: () => controller.filter.value = FormStatus.disabled,
                              ),
                              PhonebookPillTab(
                                label: 'Ended (${controller.countOf(FormStatus.expired)})',
                                icon: Icons.check_circle_outline_rounded,
                                selected: f == FormStatus.expired,
                                color: PhonebookTheme.muted,
                                onTap: () => controller.filter.value = FormStatus.expired,
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Amber-bar section header
                      Obx(() {
                        final count = controller.visible.length;
                        return PhonebookSectionHeader(
                          title: 'Forms & Polls ($count)',
                          actionLabel: controller.activeFilterCount > 0 ? 'Clear filters' : null,
                          onAction: controller.activeFilterCount > 0 ? controller.resetFilters : null,
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(color: PhonebookTheme.blue)),
                  );
                }
                if (controller.hasError.value) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load forms',
                        message: controller.errorMessage.value,
                        actionLabel: 'Retry',
                        onAction: controller.load,
                      ),
                    ),
                  );
                }
                final items = controller.visible;
                if (items.isEmpty) {
                  final hasFilters =
                      controller.activeFilterCount > 0 || controller.search.value.trim().isNotEmpty;
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      child: EmptyState(
                        icon: Icons.how_to_vote_outlined,
                        title: controller.forms.isEmpty ? 'No polls or forms yet' : 'Nothing here',
                        message: controller.forms.isEmpty
                            ? 'Create a quick poll (e.g. dinner choice) or a form with several questions.'
                            : 'Try another search or filter.',
                        // No button when there is nothing yet: the New button
                        // at the bottom right already does it.
                        actionLabel: controller.forms.isNotEmpty && hasFilters ? 'Clear Filters' : null,
                        onAction: controller.forms.isNotEmpty && hasFilters
                            ? () {
                                controller.clearSearch();
                                controller.resetFilters();
                              }
                            : null,
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final card = Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FormCard(
                          form: items[i],
                          busy: controller.busyIds.contains(items[i].id),
                          onOpen: () => Get.toNamed(Routes.operatorFormAnalytics, arguments: items[i]),
                          onEdit: () => _edit(items[i]),
                          onToggle: () => controller.toggle(items[i]),
                          onDelete: () => _confirmDelete(context, items[i]),
                        ),
                      );
                      return i < 8 ? StaggeredSlideFade(index: i, child: card) : card;
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final HostelForm form;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _FormCard({
    required this.form,
    required this.busy,
    required this.onOpen,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  /// The card's colour is its status: green running, blue upcoming, amber
  /// paused, grey ended.
  static Color _statusColor(FormStatus status) => switch (status) {
    FormStatus.active => PhonebookTheme.green,
    FormStatus.upcoming => PhonebookTheme.blue,
    FormStatus.disabled => PhonebookTheme.amber,
    _ => PhonebookTheme.muted,
  };

  static String _statusLabel(FormStatus status) => switch (status) {
    FormStatus.active => 'Active',
    FormStatus.upcoming => 'Upcoming',
    FormStatus.disabled => 'Paused',
    FormStatus.expired => 'Ended',
    FormStatus.unknown => '',
  };

  @override
  Widget build(BuildContext context) {
    final f = form;
    final accent = _statusColor(f.status);
    final poll = f.kind == FormKind.poll;
    final kindColor = poll ? PhonebookTheme.blue : const Color(0xFF6366F1);
    final rate = f.totalTargeted == 0 ? 0 : (f.totalResponded * 100 / f.totalTargeted).round();
    final statusLabel = _statusLabel(f.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(96, 64),
                  painter: CornerWavePainter(color: accent.withValues(alpha: 0.12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              f.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: PhonebookTheme.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          height: 32,
                          child: busy
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: PhonebookTheme.blue),
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  tooltip: 'More',
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: PhonebookTheme.muted),
                                  onSelected: (v) => switch (v) {
                                    'results' => onOpen(),
                                    'edit' => onEdit(),
                                    'toggle' => onToggle(),
                                    _ => onDelete(),
                                  },
                                  itemBuilder: (_) => [
                                    _menuItem('results', Icons.insights_rounded, 'Results'),
                                    _menuItem('edit', Icons.edit_rounded, 'Edit'),
                                    _menuItem(
                                      'toggle',
                                      f.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                      f.isActive ? 'Pause' : 'Activate',
                                    ),
                                    _menuItem('delete', Icons.delete_outline_rounded, 'Delete', color: PhonebookTheme.red),
                                  ],
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(
                          label: poll ? 'Poll' : 'Form',
                          icon: poll ? Icons.how_to_vote_rounded : Icons.assignment_rounded,
                          color: kindColor,
                        ),
                        if (statusLabel.isNotEmpty) _Tag(label: statusLabel, color: accent),
                        if (f.isMandatory) const _Tag(label: 'Required', color: PhonebookTheme.red),
                      ],
                    ),
                    if (f.description != null && f.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        f.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: PhonebookTheme.slate),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${f.totalResponded}',
                                      style: const TextStyle(color: PhonebookTheme.ink, fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(
                                      text: ' of ${f.totalTargeted} answered',
                                      style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              const Spacer(),
                              Text(
                                '$rate%',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: accent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: rate / 100,
                              minHeight: 6,
                              backgroundColor: accent.withValues(alpha: 0.14),
                              valueColor: AlwaysStoppedAnimation(accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      f.endTime == null
                          ? f.audience.label
                          : '${f.audience.label} · closes ${DateFormatting.dateTime(f.endTime!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PhonebookTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color ?? PhonebookTheme.slate),
        const SizedBox(width: 10),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    ),
  );
}

/// A small coloured tag: soft fill, coloured text.
class _Tag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _Tag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
