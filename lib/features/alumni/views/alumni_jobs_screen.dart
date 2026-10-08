import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../controllers/alumni_controller.dart';

class AlumniJobsScreen extends StatefulWidget {
  const AlumniJobsScreen({super.key});

  @override
  State<AlumniJobsScreen> createState() => _AlumniJobsScreenState();
}

class _AlumniJobsScreenState extends State<AlumniJobsScreen> {
  final AlumniController controller = Get.find<AlumniController>();

  @override
  void initState() {
    super.initState();
    controller.loadJobs();
  }

  void _apply(AlumniJobModel job) async {
    if (job.applyUrl != null && job.applyUrl!.isNotEmpty) {
      String url = job.applyUrl!.trim();
      if (!url.startsWith('http')) url = 'https://$url';
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (job.contactEmail != null && job.contactEmail!.isNotEmpty) {
      final emailUri = Uri.parse('mailto:${job.contactEmail}?subject=Application for ${job.title}');
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        return;
      }
    }
    Get.snackbar('Contact', 'Please reach out to ${job.postedByName}');
  }

  void _showPostJobDialog() {
    final titleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final reqsCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String jobType = 'referral';
    bool isRemote = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
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
                  Text('Post Job Opening or Referral', style: AppTextStyles.headline.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Share opportunities with fellow alumni and hostel juniors.', style: AppTextStyles.bodySm),
                  const SizedBox(height: AppDimens.gapLg),

                  AppTextField(controller: titleCtrl, label: 'Role / Job Title', hint: 'e.g. Software Engineer, Resident Doctor'),
                  const SizedBox(height: AppDimens.gapMd),
                  AppTextField(controller: companyCtrl, label: 'Company / Organization', hint: 'e.g. Google, Tata Motors, AIIMS'),
                  const SizedBox(height: AppDimens.gapMd),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: jobType,
                          decoration: InputDecoration(
                            labelText: 'Opportunity Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'referral', child: Text('Alumni Referral')),
                            DropdownMenuItem(value: 'full-time', child: Text('Full-time Job')),
                            DropdownMenuItem(value: 'internship', child: Text('Internship')),
                            DropdownMenuItem(value: 'part-time', child: Text('Part-time')),
                          ],
                          onChanged: (val) => setSheetState(() => jobType = val ?? 'referral'),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapMd),
                      Expanded(
                        child: AppTextField(controller: expCtrl, label: 'Experience', hint: 'e.g. 0-2 Years / Freshers'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapMd),

                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(controller: locationCtrl, label: 'Location', hint: 'e.g. Bangalore / Ahmedabad'),
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      FilterChip(
                        label: const Text('Remote'),
                        selected: isRemote,
                        onSelected: (val) => setSheetState(() => isRemote = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapMd),

                  AppTextField(controller: descCtrl, label: 'Job Description', hint: 'Key responsibilities...', maxLines: 3),
                  const SizedBox(height: AppDimens.gapMd),
                  AppTextField(controller: linkCtrl, label: 'Application Link (Optional)', hint: 'https://careers...'),
                  const SizedBox(height: AppDimens.gapMd),
                  AppTextField(controller: emailCtrl, label: 'Contact Email for Referral', hint: 'yourname@company.com'),
                  const SizedBox(height: AppDimens.gapLg),

                  AppButton(
                    label: 'Publish Opportunity',
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || companyCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                        Get.snackbar('Required', 'Please fill in Title, Company, and Description');
                        return;
                      }
                      Get.back();
                      await controller.postJob(
                        title: titleCtrl.text.trim(),
                        company: companyCtrl.text.trim(),
                        jobType: jobType,
                        location: locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : (isRemote ? 'Remote' : 'India'),
                        isRemote: isRemote,
                        experienceRequired: expCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        requirements: reqsCtrl.text.trim(),
                        applyUrl: linkCtrl.text.trim(),
                        contactEmail: emailCtrl.text.trim(),
                      );
                    },
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Post Referral'),
        onPressed: _showPostJobDialog,
      ),
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            overline: 'Careers & Guidance',
            title: 'Job Board & Referrals',
            subtitle: 'Openings, referrals & internships by alumni',
            expandedHeight: 180,
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              if (controller.isJobsLoading.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final jobs = controller.jobsList;
              if (jobs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: EmptyState(
                    icon: Icons.work_off_outlined,
                    title: 'No Job Openings Yet',
                    message: 'Be the first to share an alumni referral or job opening!',
                  ),
                );
              }

              return AppRefreshIndicator(
                onRefresh: controller.loadJobs,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapLg,
                    AppDimens.screenPadding,
                    AppDimens.gapXxl * 2,
                  ),
                  itemCount: jobs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppDimens.gapMd),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return AppCard(
                      padding: const EdgeInsets.all(AppDimens.cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const IconBadge(icon: Icons.work_outline_rounded, color: AppColors.primary, size: 44),
                              const SizedBox(width: AppDimens.gapMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(job.title, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            job.jobTypeDisplay,
                                            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${job.company} • ${job.location}${job.isRemote ? ' (Remote)' : ''}',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (job.description.isNotEmpty) ...[
                            const SizedBox(height: AppDimens.gapMd),
                            Text(job.description, style: AppTextStyles.bodySm),
                          ],
                          const SizedBox(height: AppDimens.gapMd),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: AppDimens.gapSm),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.primarySoft,
                                child: Text(job.postedByName.isNotEmpty ? job.postedByName[0] : 'A', style: const TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Posted by ${job.postedByName}${job.posterGraduationYear != null ? ' (${job.posterGraduationYear})' : ''}',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () => _apply(job),
                                child: const Text('Apply / Refer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
