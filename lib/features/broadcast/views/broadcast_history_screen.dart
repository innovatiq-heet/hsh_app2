import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/broadcasts/broadcast_models.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../controllers/broadcast_history_controller.dart';
import '../widgets/broadcast_widgets.dart';

/// Admin → Broadcast: sent broadcasts and a button to write a new one,
/// styled to match the Hostel Phonebook executive navy-and-slate theme.
class BroadcastHistoryScreen extends GetView<BroadcastHistoryController> {
  const BroadcastHistoryScreen({super.key});

  Future<void> _compose() async {
    final sent = await Get.toNamed(Routes.operatorBroadcastCompose);
    if (sent is Broadcast) controller.addSent(sent);
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
                              'Filter Broadcasts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: PhonebookTheme.ink,
                              ),
                            ),
                            Text(
                              'Refine by delivery channel and send status',
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
                  _sheetHeader('DELIVERY CHANNEL', Icons.campaign_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sheetChip(
                        label: 'All Channels',
                        selected: controller.channelFilter.value == null,
                        color: PhonebookTheme.blue,
                        onTap: () => controller.channelFilter.value = null,
                      ),
                      _sheetChip(
                        label: 'App + WhatsApp',
                        selected: controller.channelFilter.value == BroadcastChannel.both,
                        color: PhonebookTheme.blue,
                        onTap: () => controller.channelFilter.value = BroadcastChannel.both,
                      ),
                      _sheetChip(
                        label: 'In-App Only',
                        selected: controller.channelFilter.value == BroadcastChannel.app,
                        color: PhonebookTheme.purple,
                        onTap: () => controller.channelFilter.value = BroadcastChannel.app,
                      ),
                      _sheetChip(
                        label: 'WhatsApp Only',
                        selected: controller.channelFilter.value == BroadcastChannel.whatsapp,
                        color: PhonebookTheme.green,
                        onTap: () => controller.channelFilter.value = BroadcastChannel.whatsapp,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sheetHeader('DELIVERY STATUS', Icons.check_circle_outline_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sheetChip(
                        label: 'All Statuses',
                        selected: controller.statusFilter.value == null,
                        color: PhonebookTheme.blue,
                        onTap: () => controller.statusFilter.value = null,
                      ),
                      _sheetChip(
                        label: 'Sent',
                        selected: controller.statusFilter.value == BroadcastStatus.sent,
                        color: PhonebookTheme.green,
                        onTap: () => controller.statusFilter.value = BroadcastStatus.sent,
                      ),
                      _sheetChip(
                        label: 'Sending',
                        selected: controller.statusFilter.value == BroadcastStatus.sending,
                        color: PhonebookTheme.amber,
                        onTap: () => controller.statusFilter.value = BroadcastStatus.sending,
                      ),
                      _sheetChip(
                        label: 'Failed',
                        selected: controller.statusFilter.value == BroadcastStatus.failed,
                        color: PhonebookTheme.red,
                        onTap: () => controller.statusFilter.value = BroadcastStatus.failed,
                      ),
                    ],
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
                        'Show ${controller.visibleBroadcasts.length} ${controller.visibleBroadcasts.length == 1 ? 'Broadcast' : 'Broadcasts'}',
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
  }) => FilterChip(
    label: Text(label),
    selected: selected,
    selectedColor: color,
    checkmarkColor: Colors.white,
    labelStyle: TextStyle(
      color: selected ? Colors.white : const Color(0xFF334155),
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      fontSize: 12.5,
    ),
    backgroundColor: const Color(0xFFF1F5F9),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? color : PhonebookTheme.border),
    ),
    onSelected: (_) => onTap(),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _compose,
          backgroundColor: PhonebookTheme.blue,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.campaign_rounded),
          label: const Text('New broadcast', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: RefreshIndicator(
          onRefresh: () => controller.load(showLoading: false),
          color: PhonebookTheme.blue,
          backgroundColor: Colors.white,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) controller.loadMore();
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                Obx(
                  () => SliverPersistentHeader(
                    pinned: true,
                    delegate: PhonebookHeaderDelegate(
                      overline: controller.isLeaderView.value ? 'Group Leader' : 'Admin',
                      title: controller.isLeaderView.value ? 'Group Broadcasts' : 'Broadcasts',
                      topPadding: MediaQuery.of(context).padding.top,
                      onLeadingTap: () => Navigator.of(context).maybePop(),
                    trailing: Obx(() {
                      final loading = controller.isLoading.value;
                      return PhonebookHeaderCircleButton(
                        icon: Icons.sync_rounded,
                        tooltip: 'Refresh broadcasts',
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
                            icon: Icons.campaign_rounded,
                            label: '${controller.total.value} sent',
                          ),
                          PhonebookHeaderPill(
                            icon: Icons.groups_rounded,
                            label: '${controller.totalReached} reached',
                          ),
                        ],
                      ),
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
                        // 3 Count Cards matching Phonebook theme
                        Obx(
                          () => Row(
                            children: [
                              Expanded(
                                child: PhonebookCountCard(
                                  value: '${controller.total.value}',
                                  label: 'Total sent',
                                  icon: Icons.campaign_outlined,
                                  color: PhonebookTheme.blue,
                                  bgColor: PhonebookTheme.blueSoft,
                                  onTap: controller.resetFilters,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PhonebookCountCard(
                                  value: '${controller.totalReached}',
                                  label: 'Reached',
                                  icon: Icons.groups_outlined,
                                  color: PhonebookTheme.amber,
                                  bgColor: PhonebookTheme.amberSoft,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PhonebookCountCard(
                                  value: '${controller.totalRead}',
                                  label: 'Read',
                                  icon: Icons.done_all_rounded,
                                  color: PhonebookTheme.green,
                                  bgColor: PhonebookTheme.greenSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Search bar + Filter button
                        Obx(
                          () => PhonebookSearchFilterBar(
                            controller: controller.searchController,
                            hintText: 'Search title, message, tag...',
                            onChanged: controller.onSearchChanged,
                            hasQuery: controller.search.value.isNotEmpty,
                            onClear: controller.clearSearch,
                            onFilterTap: () => _showFilterBottomSheet(context),
                            activeFilterCount: controller.activeFilterCount,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Channel pill tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Obx(() {
                            final current = controller.channelFilter.value;
                            return Row(
                              children: [
                                PhonebookPillTab(
                                  label: 'All (${controller.countByChannel(null)})',
                                  selected: current == null,
                                  color: PhonebookTheme.blue,
                                  onTap: () => controller.channelFilter.value = null,
                                ),
                                PhonebookPillTab(
                                  label: 'App + WA (${controller.countByChannel(BroadcastChannel.both)})',
                                  icon: Icons.campaign_rounded,
                                  selected: current == BroadcastChannel.both,
                                  color: PhonebookTheme.blue,
                                  onTap: () => controller.channelFilter.value = BroadcastChannel.both,
                                ),
                                PhonebookPillTab(
                                  label: 'In-App (${controller.countByChannel(BroadcastChannel.app)})',
                                  icon: Icons.notifications_active_rounded,
                                  selected: current == BroadcastChannel.app,
                                  color: PhonebookTheme.purple,
                                  onTap: () => controller.channelFilter.value = BroadcastChannel.app,
                                ),
                                PhonebookPillTab(
                                  label: 'WhatsApp (${controller.countByChannel(BroadcastChannel.whatsapp)})',
                                  icon: Icons.chat_rounded,
                                  selected: current == BroadcastChannel.whatsapp,
                                  color: PhonebookTheme.green,
                                  onTap: () => controller.channelFilter.value = BroadcastChannel.whatsapp,
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 16),

                        // Amber-bar section header
                        Obx(() {
                          final count = controller.visibleBroadcasts.length;
                          return PhonebookSectionHeader(
                            title: 'Sent broadcasts ($count)',
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
                          title: 'Could not load broadcasts',
                          message: controller.errorMessage.value,
                          actionLabel: 'Retry',
                          onAction: controller.load,
                        ),
                      ),
                    );
                  }
                  final items = controller.visibleBroadcasts;
                  if (items.isEmpty) {
                    final hasFilters =
                        controller.activeFilterCount > 0 || controller.search.value.trim().isNotEmpty;
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                        child: EmptyState(
                          icon: Icons.campaign_outlined,
                          title: controller.broadcasts.isEmpty ? 'No broadcasts yet' : 'No matching broadcasts',
                          message: controller.broadcasts.isEmpty
                              ? 'Send a message to students by tag or pick them one by one.'
                              : 'Try clearing active filters or modifying your search query.',
                          actionLabel: hasFilters ? 'Clear Filters' : 'New broadcast',
                          actionIcon: hasFilters ? Icons.filter_alt_off_rounded : Icons.add_rounded,
                          onAction: hasFilters
                              ? () {
                                  controller.clearSearch();
                                  controller.resetFilters();
                                }
                              : _compose,
                        ),
                      ),
                    );
                  }
                  final showLoadMore = controller.hasMore &&
                      controller.activeFilterCount == 0 &&
                      controller.search.value.trim().isEmpty;
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
                    sliver: SliverList.builder(
                      itemCount: items.length + (showLoadMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(color: PhonebookTheme.blue)),
                          );
                        }
                        final b = items[i];
                        final card = Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: BroadcastCard(
                            broadcast: b,
                            onTap: () => Get.toNamed(Routes.operatorBroadcastDetail, arguments: b),
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
      ),
    );
  }
}
