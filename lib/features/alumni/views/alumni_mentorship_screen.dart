import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../controllers/alumni_controller.dart';

class AlumniMentorshipScreen extends StatefulWidget {
  const AlumniMentorshipScreen({super.key});

  @override
  State<AlumniMentorshipScreen> createState() => _AlumniMentorshipScreenState();
}

class _AlumniMentorshipScreenState extends State<AlumniMentorshipScreen> with SingleTickerProviderStateMixin {
  final AlumniController controller = Get.find<AlumniController>();
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    controller.loadMentors();
    controller.loadMyMentorshipRequests();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  void _showRequestDialog(AlumniProfileModel mentor) {
    final topicCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Request Guidance from ${mentor.name}', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(mentor.currentRoleLine, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppDimens.gapLg),
              TextField(
                controller: topicCtrl,
                decoration: InputDecoration(
                  labelText: 'Topic',
                  hintText: 'e.g. Software Interview, GATE Prep, Resume Review',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: AppDimens.gapMd),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message / Questions',
                  hintText: 'Describe what you would like guidance on...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: AppDimens.gapLg),
              AppButton(
                label: 'Send Request',
                onPressed: () async {
                  if (topicCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                    Get.snackbar('Required', 'Please fill in topic and message');
                    return;
                  }
                  Get.back();
                  await controller.sendMentorshipRequest(
                    mentorStudentId: mentor.studentId,
                    topic: topicCtrl.text.trim(),
                    message: messageCtrl.text.trim(),
                  );
                },
              ),
              const SizedBox(height: AppDimens.gapMd),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        title: const Text('Mentorship & Guidance'),
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.secondary,
          tabs: const [
            Tab(text: 'Alumni Mentors'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          Obx(() {
            if (controller.isMentorshipLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final mentors = controller.mentorsList;
            if (mentors.isEmpty) {
              return const EmptyState(
                icon: Icons.psychology_outlined,
                title: 'No Mentors Listed Yet',
                message: 'Alumni who opt-in to guide juniors will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              itemCount: mentors.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppDimens.gapMd),
              itemBuilder: (context, index) {
                final mentor = mentors[index];
                return AppCard(
                  padding: const EdgeInsets.all(AppDimens.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primarySoft,
                            child: Text(mentor.initials, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                          const SizedBox(width: AppDimens.gapMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mentor.name, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  mentor.currentRoleLine.isNotEmpty ? mentor.currentRoleLine : mentor.batchLabel,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (mentor.topicsList.isNotEmpty) ...[
                        const SizedBox(height: AppDimens.gapMd),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: mentor.topicsList
                              .map(
                                (t) => Chip(
                                  label: Text(t, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                                  backgroundColor: AppColors.primarySoft,
                                  padding: EdgeInsets.zero,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: AppDimens.gapMd),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Get.toNamed(Routes.alumniProfile, arguments: mentor),
                              child: const Text('View Profile'),
                            ),
                          ),
                          const SizedBox(width: AppDimens.gapSm),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Request'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _showRequestDialog(mentor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          }),

          Obx(() {
            final sent = controller.sentRequests;
            final received = controller.receivedRequests;

            if (sent.isEmpty && received.isEmpty) {
              return const EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: 'No Mentorship Requests',
                message: 'Guidance requests you send or receive will appear here.',
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              children: [
                if (received.isNotEmpty) ...[
                  Text('Incoming Requests from Juniors', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppDimens.gapSm),
                  ...received.map((req) => _buildReceivedRequestCard(req)),
                  const SizedBox(height: AppDimens.gapLg),
                ],
                if (sent.isNotEmpty) ...[
                  Text('Requests Sent by You', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppDimens.gapSm),
                  ...sent.map((req) => _buildSentRequestCard(req)),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSentRequestCard(AlumniMentorshipRequestModel req) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Mentor: ${req.mentorName}', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                ),
                _buildStatusBadge(req.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Topic: ${req.topic}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(req.message, style: AppTextStyles.bodySm),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedRequestCard(AlumniMentorshipRequestModel req) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('From: ${req.requesterName} (Room ${req.requesterRoom})', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                ),
                _buildStatusBadge(req.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Topic: ${req.topic}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(req.message, style: AppTextStyles.bodySm),
            if (req.status == 'pending') ...[
              const SizedBox(height: AppDimens.gapMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.updateMentorshipStatus(req.id, 'declined'),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen, foregroundColor: Colors.white),
                      onPressed: () => controller.updateMentorshipStatus(req.id, 'accepted'),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'accepted':
        color = AppColors.successGreen;
        break;
      case 'declined':
        color = AppColors.cancelledRed;
        break;
      case 'completed':
        color = AppColors.primary;
        break;
      default:
        color = AppColors.warningOrange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}
