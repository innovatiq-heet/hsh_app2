import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../controllers/alumni_controller.dart';

class AlumniDirectoryScreen extends StatefulWidget {
  const AlumniDirectoryScreen({super.key});

  @override
  State<AlumniDirectoryScreen> createState() => _AlumniDirectoryScreenState();
}

class _AlumniDirectoryScreenState extends State<AlumniDirectoryScreen> {
  final AlumniController controller = Get.find<AlumniController>();
  final TextEditingController searchController = TextEditingController();

  final List<int> years = [2026, 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015];
  final List<String> fields = ['Engineering', 'Medical', 'Commerce', 'Management', 'Science', 'Law', 'Arts'];

  @override
  void initState() {
    super.initState();
    searchController.text = controller.directorySearch.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadDirectory();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _openLinkedIn(String url) async {
    if (url.trim().isEmpty) return;
    String effective = url.trim();
    if (!effective.startsWith('http://') && !effective.startsWith('https://')) {
      effective = 'https://$effective';
    }
    final uri = Uri.tryParse(effective);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('LinkedIn', 'Could not open URL: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverGradientHeader(
            overline: 'Alumni Network',
            title: 'Directory & Search',
            subtitle: 'Find alumni by Batch Year, Degree, Company, or City',
            expandedHeight: 180,
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapMd,
                AppDimens.screenPadding,
                AppDimens.gapSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: searchController,
                    label: 'Search Directory',
                    hint: 'Search by name, company, city, role...',
                    prefixIcon: Icons.search_rounded,
                    suffix: Obx(
                      () => controller.directorySearch.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                searchController.clear();
                                controller.directorySearch.value = '';
                                controller.loadDirectory();
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    onChanged: (val) {
                      controller.directorySearch.value = val;
                      controller.loadDirectory(showSpinner: false);
                    },
                  ),
                  const SizedBox(height: AppDimens.gapMd),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        Obx(
                          () => FilterChip(
                            label: const Text('Mentors Only'),
                            avatar: Icon(
                              Icons.psychology_rounded,
                              size: 16,
                              color: controller.onlyMentors.value ? Colors.white : AppColors.primary,
                            ),
                            selected: controller.onlyMentors.value,
                            selectedColor: AppColors.primary,
                            labelStyle: AppTextStyles.caption.copyWith(
                              color: controller.onlyMentors.value ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) {
                              controller.onlyMentors.value = val;
                              controller.loadDirectory();
                            },
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),

                        Obx(
                          () => PopupMenuButton<int?>(
                            initialValue: controller.selectedBatchYear.value,
                            onSelected: (year) {
                              controller.selectedBatchYear.value = year;
                              controller.loadDirectory();
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: null, child: Text('All Batch Years')),
                              ...years.map((y) => PopupMenuItem(value: y, child: Text('Batch $y'))),
                            ],
                            child: Chip(
                              label: Text(
                                controller.selectedBatchYear.value != null
                                    ? 'Batch ${controller.selectedBatchYear.value}'
                                    : 'Batch Year',
                                style: AppTextStyles.caption.copyWith(
                                  color: controller.selectedBatchYear.value != null
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: controller.selectedBatchYear.value != null
                                  ? AppColors.primary
                                  : AppColors.surface,
                              deleteIcon: controller.selectedBatchYear.value != null
                                  ? const Icon(Icons.close_rounded, size: 16, color: Colors.white)
                                  : const Icon(Icons.arrow_drop_down_rounded, size: 18),
                              onDeleted: controller.selectedBatchYear.value != null
                                  ? () {
                                      controller.selectedBatchYear.value = null;
                                      controller.loadDirectory();
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.gapSm),

                        Obx(
                          () => PopupMenuButton<String?>(
                            initialValue: controller.selectedField.value.isNotEmpty
                                ? controller.selectedField.value
                                : null,
                            onSelected: (field) {
                              controller.selectedField.value = field ?? '';
                              controller.loadDirectory();
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: null, child: Text('All Fields')),
                              ...fields.map((f) => PopupMenuItem(value: f, child: Text(f))),
                            ],
                            child: Chip(
                              label: Text(
                                controller.selectedField.value.isNotEmpty
                                    ? controller.selectedField.value
                                    : 'Field/Degree',
                                style: AppTextStyles.caption.copyWith(
                                  color: controller.selectedField.value.isNotEmpty
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: controller.selectedField.value.isNotEmpty
                                  ? AppColors.primary
                                  : AppColors.surface,
                              deleteIcon: controller.selectedField.value.isNotEmpty
                                  ? const Icon(Icons.close_rounded, size: 16, color: Colors.white)
                                  : const Icon(Icons.arrow_drop_down_rounded, size: 18),
                              onDeleted: controller.selectedField.value.isNotEmpty
                                  ? () {
                                      controller.selectedField.value = '';
                                      controller.loadDirectory();
                                    }
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              if (controller.isDirectoryLoading.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final list = controller.directoryList;
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: EmptyState(
                    icon: Icons.person_search_rounded,
                    title: 'No Alumni Found',
                    message: 'Try clearing your filters or searching with another keyword.',
                  ),
                );
              }

              return AppRefreshIndicator(
                onRefresh: controller.loadDirectory,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapSm,
                    AppDimens.screenPadding,
                    AppDimens.gapXxl,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppDimens.gapMd),
                  itemBuilder: (context, index) {
                    final alumnus = list[index];
                    return _buildAlumniCard(alumnus);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAlumniCard(AlumniProfileModel alumnus) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      onTap: () => Get.toNamed(Routes.alumniProfile, arguments: alumnus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  alumnus.initials,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alumnus.name,
                            style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (alumnus.isMentor)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'MENTOR',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (alumnus.currentRoleLine.isNotEmpty)
                      Text(
                        alumnus.currentRoleLine,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (alumnus.degree.isNotEmpty || alumnus.fieldOfStudy.isNotEmpty)
                      Text(
                        alumnus.degree.isNotEmpty ? alumnus.degree : alumnus.fieldOfStudy,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppDimens.gapSm),
          Row(
            children: [
              if (alumnus.graduationYear != null) ...[
                const Icon(Icons.school_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Batch ${alumnus.graduationYear}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: AppDimens.gapMd),
              ],
              if (alumnus.currentCity.isNotEmpty) ...[
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    alumnus.currentCity,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (alumnus.hasLinkedIn)
                InkWell(
                  onTap: () => _openLinkedIn(alumnus.linkedinUrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0077B5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 14, color: Color(0xFF0077B5)),
                        const SizedBox(width: 4),
                        Text(
                          'LinkedIn',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF0077B5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
