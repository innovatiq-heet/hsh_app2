import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/enums/complaint_status.dart';
import '../../../core/network/responses/complaints/complaint_response.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../controllers/complaint_detail_controller.dart';
import '../widgets/complaint_detail_cards.dart';

/// A student's own complaint. Read-only: only solvers change the status.
class ComplaintDetailScreen extends GetView<ComplaintDetailController> {
  const ComplaintDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Obx(
      () => Scaffold(
        backgroundColor: PhonebookTheme.bg,
        // The back button lives in the sliver header, which an error hides.
        appBar: controller.hasError.value
            ? AppBar(
                backgroundColor: const Color(0xFF03192E),
                foregroundColor: Colors.white,
                title: const Text(
                  'Complaint Details',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
        body: AsyncStateView(
          isLoading: controller.isLoading.value,
          hasError: controller.hasError.value,
          errorMessage: controller.errorMessage.value,
          onRetry: controller.load,
          loadingWidget: const SafeArea(child: SkeletonList()),
          builder: (context) => Obx(() {
            final c = controller.complaint.value!;
            return AppRefreshIndicator(
              onRefresh: () => controller.load(showLoading: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: PhonebookHeaderDelegate(
                      overline: 'Complaint #${c.id}',
                      title: 'Complaint Details',
                      subtitle: '${c.category} · ${c.item}',
                      topPadding: topPadding,
                      onLeadingTap: () => Get.back(),
                      pills: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          PhonebookHeaderPill(
                            icon: Icons.calendar_today_rounded,
                            label: 'Submitted ${DateFormatting.dateOnly(c.createdAt)}',
                          ),
                          PhonebookHeaderPill(
                            icon: c.status.icon,
                            label: c.status.label,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _DetailSectionHeader(title: 'Resolution progress'),
                          ComplaintTimelineCard(complaint: c),
                          const SizedBox(height: 20),
                          const _DetailSectionHeader(title: 'Issue summary'),
                          ComplaintIssueCard(complaint: c),
                          const SizedBox(height: 20),
                          const _DetailSectionHeader(title: 'Complaint details'),
                          _MetaDetailsCard(complaint: c),
                          if (c.hasImage) ...[
                            const SizedBox(height: 20),
                            const _DetailSectionHeader(title: 'Attached photo'),
                            ComplaintPhotoCard(complaint: c),
                          ],
                          const SizedBox(height: 20),
                          const _SupportNoticeCard(),
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
    );
  }
}

class _DetailSectionHeader extends StatelessWidget {
  final String title;

  const _DetailSectionHeader({required this.title});

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
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: PhonebookTheme.slate,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaDetailsCard extends StatelessWidget {
  final ComplaintResponse complaint;

  const _MetaDetailsCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return PhonebookCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          InfoRow(
            icon: Icons.meeting_room_outlined,
            label: 'Room Number',
            value: complaint.roomId,
          ),
          const Divider(height: 1, color: PhonebookTheme.border),
          InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Submitted At',
            value: DateFormatting.dateTime(complaint.createdAt),
          ),
          const Divider(height: 1, color: PhonebookTheme.border),
          InfoRow(
            icon: Icons.update_rounded,
            label: 'Last Updated',
            value: DateFormatting.dateTime(complaint.updatedAt),
          ),
        ],
      ),
    );
  }
}

class _SupportNoticeCard extends StatelessWidget {
  const _SupportNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhonebookTheme.blueSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.headset_mic_outlined,
            size: 20,
            color: PhonebookTheme.blue,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need urgent assistance?',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: PhonebookTheme.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'For emergency issues (water overflow, short circuit), please report directly to the hostel warden desk.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: PhonebookTheme.slate,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
