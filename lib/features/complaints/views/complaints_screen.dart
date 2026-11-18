import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/enums/complaint_status.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../controllers/complaints_controller.dart';
import '../widgets/complaint_card.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _searchCtrl = TextEditingController();

  ComplaintsController get controller => Get.find<ComplaintsController>();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: PhonebookTheme.bg,
      body: Obx(
        () => AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          loadingWidget: _ComplaintsShimmer(topPadding: topPadding, canPop: canPop),
          builder: (context) => Obx(() {
            final all = controller.complaints;
            final filtered = controller.filteredComplaints;
            final selected = controller.selectedStatus.value;
            final hasQuery = controller.searchQuery.value.trim().isNotEmpty;

            return AppRefreshIndicator(
              onRefresh: () => controller.load(showLoading: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: PhonebookHeaderDelegate(
                      overline: 'Help Desk',
                      title: 'Complaints',
                      subtitle: 'Report and track maintenance issues in your room',
                      topPadding: topPadding,
                      showLeading: canPop,
                      onLeadingTap: () => Get.back(),
                      trailing: PhonebookHeaderCircleButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Refresh',
                        onTap: () => controller.load(showLoading: false),
                      ),
                    ),
                  ),

                  // ── Executive Metric Count Cards ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: PhonebookCountCard(
                              value: '${controller.countOf(ComplaintStatus.open)}',
                              label: 'Submitted',
                              icon: Icons.hourglass_top_rounded,
                              color: PhonebookTheme.amber,
                              bgColor: PhonebookTheme.amberSoft,
                              highlighted: selected == ComplaintStatus.open,
                              onTap: () => controller.setStatus(ComplaintStatus.open),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PhonebookCountCard(
                              value: '${controller.countOf(ComplaintStatus.inProgress)}',
                              label: 'In progress',
                              icon: Icons.build_circle_outlined,
                              color: PhonebookTheme.blue,
                              bgColor: PhonebookTheme.blueSoft,
                              highlighted: selected == ComplaintStatus.inProgress,
                              onTap: () => controller.setStatus(ComplaintStatus.inProgress),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PhonebookCountCard(
                              value: '${controller.countOf(ComplaintStatus.resolved)}',
                              label: 'Resolved',
                              icon: Icons.check_circle_outline_rounded,
                              color: PhonebookTheme.green,
                              bgColor: PhonebookTheme.greenSoft,
                              highlighted: selected == ComplaintStatus.resolved,
                              onTap: () => controller.setStatus(ComplaintStatus.resolved),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Search Bar ──
                  if (all.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: PhonebookSearchFilterBar(
                          controller: _searchCtrl,
                          hintText: 'Search by item, category, or comment...',
                          hasQuery: hasQuery,
                          onChanged: (v) => controller.searchQuery.value = v,
                          onClear: () {
                            _searchCtrl.clear();
                            controller.searchQuery.value = '';
                          },
                        ),
                      ),
                    ),

                    // ── Status Filter Pill Tabs ──
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            PhonebookPillTab(
                              label: 'All (${all.length})',
                              selected: selected == null,
                              color: PhonebookTheme.blue,
                              onTap: () => controller.selectedStatus.value = null,
                            ),
                            for (final status in ComplaintStatus.values)
                              PhonebookPillTab(
                                label: '${status.label} (${controller.countOf(status)})',
                                icon: status.icon,
                                selected: selected == status,
                                color: _statusTabColor(status),
                                onTap: () => controller.setStatus(status),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── Complaints List / Empty State ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: all.isEmpty
                          ? EmptyState(
                              icon: Icons.support_agent_outlined,
                              title: 'No complaints yet',
                              message: controller.canSubmit
                                  ? 'Something not working? Raise a complaint and the maintenance team will pick it up.'
                                  : 'Room complaints are available to students with an assigned room.',
                            )
                          : filtered.isEmpty
                              ? EmptyState(
                                  icon: Icons.filter_list_off_rounded,
                                  title: 'No matching complaints',
                                  message: 'Try clearing your search or selecting another status.',
                                  actionLabel: 'Reset filters',
                                  onAction: () {
                                    _searchCtrl.clear();
                                    controller.searchQuery.value = '';
                                    controller.selectedStatus.value = null;
                                  },
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _AmberSectionHeader(
                                      title: 'My complaints',
                                      count: filtered.length,
                                    ),
                                    for (int i = 0; i < filtered.length; i++)
                                      StaggeredSlideFade(
                                        index: i,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppDimens.gapMd,
                                          ),
                                          child: ComplaintCard(
                                            complaint: filtered[i],
                                            onTap: () => Get.toNamed(
                                              Routes.complaintDetail,
                                              arguments: filtered[i].id,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
      floatingActionButton: controller.canSubmit
          ? FloatingActionButton.extended(
              heroTag: null,
              backgroundColor: PhonebookTheme.blue,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () => Get.toNamed(Routes.complaintAdd)?.then((saved) {
                if (saved == true) controller.load(showLoading: false);
              }),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New complaint',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  static Color _statusTabColor(ComplaintStatus status) {
    return switch (status) {
      ComplaintStatus.open => PhonebookTheme.amber,
      ComplaintStatus.inProgress => PhonebookTheme.blue,
      ComplaintStatus.resolved => PhonebookTheme.green,
      ComplaintStatus.closed => PhonebookTheme.slate,
    };
  }
}

/// Executive section header matching `PhonebookSectionHeader` while preserving exact text casing.
class _AmberSectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _AmberSectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: PhonebookTheme.slate,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: PhonebookTheme.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: PhonebookTheme.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComplaintsShimmer extends StatelessWidget {
  final double topPadding;
  final bool canPop;

  const _ComplaintsShimmer({required this.topPadding, required this.canPop});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: PhonebookHeaderDelegate(
            overline: 'Help Desk',
            title: 'Complaints',
            subtitle: 'Report and track maintenance issues in your room',
            topPadding: topPadding,
            showLeading: canPop,
            onLeadingTap: () {},
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 76,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: PhonebookTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SkeletonLoader(
                                    height: 26,
                                    width: 26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  SkeletonLoader(
                                    height: 20,
                                    width: 24,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                              SkeletonLoader(
                                height: 11,
                                width: 58,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                SkeletonLoader(
                  height: 48,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(16),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppDimens.gapMd),
                    child: _ComplaintCardShimmer(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComplaintCardShimmer extends StatelessWidget {
  const _ComplaintCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhonebookTheme.border, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SkeletonLoader(
            height: 40,
            width: 40,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  height: 15,
                  width: 130,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                SkeletonLoader(
                  height: 11,
                  width: 90,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.gapSm),
          SkeletonLoader(
            height: 24,
            width: 72,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }
}
