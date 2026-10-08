import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/section_header.dart';
import '../controllers/alumni_controller.dart';

class AlumniProfileScreen extends StatelessWidget {
  const AlumniProfileScreen({super.key});

  void _openUrl(String url) async {
    if (url.trim().isEmpty) return;
    String effective = url.trim();
    if (!effective.startsWith('http://') && !effective.startsWith('https://')) {
      effective = 'https://$effective';
    }
    final uri = Uri.tryParse(effective);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('Link', 'Could not open URL: $url');
    }
  }

  void _showMentorshipDialog(BuildContext context, AlumniProfileModel alumnus, AlumniController controller) {
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
              Text(
                'Request Mentorship & Guidance',
                style: AppTextStyles.headline.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect with ${alumnus.name} for career advice, interview tips, or academic guidance.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.gapLg),
              TextField(
                controller: topicCtrl,
                decoration: InputDecoration(
                  labelText: 'Guidance Topic',
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
                  hintText: 'Introduce yourself, your room number/year, and what you would like advice on...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: AppDimens.gapLg),
              AppButton(
                label: 'Send Guidance Request',
                onPressed: () async {
                  if (topicCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                    Get.snackbar('Required', 'Please fill in both topic and message');
                    return;
                  }
                  Get.back();
                  await controller.sendMentorshipRequest(
                    mentorStudentId: alumnus.studentId,
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
    final AlumniController controller = Get.find<AlumniController>();
    final AlumniProfileModel? argAlumnus = Get.arguments as AlumniProfileModel?;

    return Obx(() {
      final isMyProfile = argAlumnus == null ||
          (controller.myProfile.value != null &&
              controller.myProfile.value!.studentId == argAlumnus.studentId);
      final profile = isMyProfile ? controller.myProfile.value : argAlumnus;

      if (profile == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          slivers: [
            SliverGradientHeader(
              overline: profile.batchLabel,
              title: profile.name.isNotEmpty ? profile.name : 'Alumni Profile',
              subtitle: profile.currentRoleLine.isNotEmpty
                  ? profile.currentRoleLine
                  : (profile.degree.isNotEmpty ? profile.degree : 'Hostel Resident'),
              expandedHeight: 220,
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Get.back(),
              ),
              actions: [
                if (isMyProfile)
                  HeaderIconButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Edit Profile',
                    onPressed: () => Get.toNamed(Routes.alumniEditProfile),
                  ),
              ],
              child: Row(
                children: [
                  if (profile.pastRoomNumber.isNotEmpty)
                    HeaderPill(
                      icon: Icons.meeting_room_outlined,
                      label: 'Room ${profile.pastRoomNumber}',
                    ),
                  if (profile.yearsStayed.isNotEmpty) ...[
                    const SizedBox(width: AppDimens.gapSm),
                    HeaderPill(
                      icon: Icons.date_range_outlined,
                      label: profile.yearsStayed,
                    ),
                  ],
                  if (profile.isMentor) ...[
                    const SizedBox(width: AppDimens.gapSm),
                    const HeaderPill(
                      icon: Icons.psychology_outlined,
                      label: 'Mentor',
                    ),
                  ],
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapLg,
                  AppDimens.screenPadding,
                  AppDimens.gapXxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Academics & Hostel Stay'),
                    AppCard(
                      padding: const EdgeInsets.all(AppDimens.cardPadding),
                      child: Column(
                        children: [
                          InfoRow(
                            icon: Icons.school_outlined,
                            label: 'Degree',
                            value: profile.degree.isNotEmpty ? profile.degree : 'Not specified',
                          ),
                          if (profile.fieldOfStudy.isNotEmpty)
                            InfoRow(
                              icon: Icons.category_outlined,
                              label: 'Field / Stream',
                              value: profile.fieldOfStudy,
                            ),
                          if (profile.graduationYear != null)
                            InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Graduation Year',
                              value: profile.graduationYear.toString(),
                            ),
                          InfoRow(
                            icon: Icons.meeting_room_outlined,
                            label: 'Past Hostel Room',
                            value: profile.pastRoomNumber.isNotEmpty ? profile.pastRoomNumber : 'Not specified',
                          ),
                          if (profile.yearsStayed.isNotEmpty)
                            InfoRow(
                              icon: Icons.timelapse_outlined,
                              label: 'Years Stayed at Hostel',
                              value: profile.yearsStayed,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapXl),

                    const SectionHeader(title: 'Current Workplace & Designation'),
                    AppCard(
                      padding: const EdgeInsets.all(AppDimens.cardPadding),
                      child: Column(
                        children: [
                          InfoRow(
                            icon: Icons.business_outlined,
                            label: 'Current Company / Org',
                            value: profile.currentCompany.isNotEmpty ? profile.currentCompany : 'Not specified',
                          ),
                          InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Current Designation',
                            value: profile.currentDesignation.isNotEmpty ? profile.currentDesignation : 'Not specified',
                          ),
                          InfoRow(
                            icon: Icons.location_city_outlined,
                            label: 'Current City',
                            value: profile.currentCity.isNotEmpty
                                ? '${profile.currentCity}, ${profile.currentCountry}'
                                : 'Not specified',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapXl),

                    const SectionHeader(title: 'Networking & Profiles'),
                    AppCard(
                      padding: const EdgeInsets.all(AppDimens.cardPadding),
                      child: Column(
                        children: [
                          if (profile.hasLinkedIn) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0077B5).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.link_rounded, color: Color(0xFF0077B5)),
                              ),
                              title: const Text('LinkedIn Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                profile.linkedinUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF0077B5)),
                              ),
                              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                              onTap: () => _openUrl(profile.linkedinUrl),
                            ),
                          ] else ...[
                            Text(
                              isMyProfile
                                  ? 'Add your LinkedIn profile link to help fellow alumni & juniors connect.'
                                  : 'No LinkedIn link provided.',
                              style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                          if (profile.bio.isNotEmpty) ...[
                            const SizedBox(height: AppDimens.gapMd),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: AppDimens.gapMd),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('About & Bio', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(profile.bio, style: AppTextStyles.bodySm),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapXl),

                    if (profile.isMentor) ...[
                      const SectionHeader(title: 'Mentorship & Junior Guidance'),
                      AppCard(
                        padding: const EdgeInsets.all(AppDimens.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: AppColors.successGreen, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Available to guide hostel juniors',
                                  style: AppTextStyles.title.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                              ],
                            ),
                            if (profile.topicsList.isNotEmpty) ...[
                              const SizedBox(height: AppDimens.gapMd),
                              Text('Guidance Topics:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: AppDimens.gapSm),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: profile.topicsList
                                    .map(
                                      (topic) => Chip(
                                        label: Text(topic, style: AppTextStyles.caption),
                                        backgroundColor: AppColors.primarySoft,
                                        padding: EdgeInsets.zero,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (!isMyProfile) ...[
                              const SizedBox(height: AppDimens.gapLg),
                              AppButton(
                                label: 'Request Career / Guidance Session',
                                icon: Icons.psychology_outlined,
                                onPressed: () => _showMentorshipDialog(context, profile, controller),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    if (isMyProfile) ...[
                      const SizedBox(height: AppDimens.gapXl),
                      AppButton(
                        label: 'Edit My Alumni Profile',
                        icon: Icons.edit_rounded,
                        onPressed: () => Get.toNamed(Routes.alumniEditProfile),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
