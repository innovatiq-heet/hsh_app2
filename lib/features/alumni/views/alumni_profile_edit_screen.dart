import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/section_header.dart';
import '../controllers/alumni_controller.dart';

class AlumniProfileEditScreen extends StatefulWidget {
  const AlumniProfileEditScreen({super.key});

  @override
  State<AlumniProfileEditScreen> createState() => _AlumniProfileEditScreenState();
}

class _AlumniProfileEditScreenState extends State<AlumniProfileEditScreen> {
  final AlumniController controller = Get.find<AlumniController>();

  late TextEditingController nameCtrl;
  late TextEditingController degreeCtrl;
  late TextEditingController fieldCtrl;
  late TextEditingController gradYearCtrl;
  late TextEditingController pastRoomCtrl;
  late TextEditingController yearsStayedCtrl;
  late TextEditingController companyCtrl;
  late TextEditingController designationCtrl;
  late TextEditingController cityCtrl;
  late TextEditingController countryCtrl;
  late TextEditingController linkedinCtrl;
  late TextEditingController bioCtrl;
  late TextEditingController mentorshipTopicsCtrl;

  bool isMentor = false;

  @override
  void initState() {
    super.initState();
    final p = controller.myProfile.value;
    nameCtrl = TextEditingController(text: p?.name ?? '');
    degreeCtrl = TextEditingController(text: p?.degree ?? '');
    fieldCtrl = TextEditingController(text: p?.fieldOfStudy ?? '');
    gradYearCtrl = TextEditingController(text: p?.graduationYear?.toString() ?? '');
    pastRoomCtrl = TextEditingController(text: p?.pastRoomNumber ?? '');
    yearsStayedCtrl = TextEditingController(text: p?.yearsStayed ?? '');
    companyCtrl = TextEditingController(text: p?.currentCompany ?? '');
    designationCtrl = TextEditingController(text: p?.currentDesignation ?? '');
    cityCtrl = TextEditingController(text: p?.currentCity ?? '');
    countryCtrl = TextEditingController(text: p?.currentCountry ?? 'India');
    linkedinCtrl = TextEditingController(text: p?.linkedinUrl ?? '');
    bioCtrl = TextEditingController(text: p?.bio ?? '');
    mentorshipTopicsCtrl = TextEditingController(text: p?.mentorshipTopics ?? '');
    isMentor = p?.isMentor ?? false;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    degreeCtrl.dispose();
    fieldCtrl.dispose();
    gradYearCtrl.dispose();
    pastRoomCtrl.dispose();
    yearsStayedCtrl.dispose();
    companyCtrl.dispose();
    designationCtrl.dispose();
    cityCtrl.dispose();
    countryCtrl.dispose();
    linkedinCtrl.dispose();
    bioCtrl.dispose();
    mentorshipTopicsCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final updated = AlumniProfileModel(
      studentId: controller.myProfile.value?.studentId ?? 0,
      name: nameCtrl.text.trim(),
      degree: degreeCtrl.text.trim(),
      fieldOfStudy: fieldCtrl.text.trim(),
      graduationYear: int.tryParse(gradYearCtrl.text.trim()),
      pastRoomNumber: pastRoomCtrl.text.trim(),
      yearsStayed: yearsStayedCtrl.text.trim(),
      currentCompany: companyCtrl.text.trim(),
      currentDesignation: designationCtrl.text.trim(),
      currentCity: cityCtrl.text.trim(),
      currentCountry: countryCtrl.text.trim().isNotEmpty ? countryCtrl.text.trim() : 'India',
      linkedinUrl: linkedinCtrl.text.trim(),
      bio: bioCtrl.text.trim(),
      isMentor: isMentor,
      mentorshipTopics: mentorshipTopicsCtrl.text.trim(),
      isVerified: true,
      isPublic: true,
    );

    final success = await controller.saveMyProfile(updated);
    if (success) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            overline: 'Alumni Profile',
            title: 'Edit Profile',
            subtitle: 'Keep your hostel records & workplace updated',
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
                AppDimens.gapLg,
                AppDimens.screenPadding,
                AppDimens.gapXxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Basic Info'),
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.cardPadding),
                    child: Column(
                      children: [
                        AppTextField(
                          controller: nameCtrl,
                          label: 'Full Name',
                          hint: 'e.g. Hardik Patel',
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        AppTextField(
                          controller: degreeCtrl,
                          label: 'Degree',
                          hint: 'e.g. B.Tech Computer Engineering',
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        AppTextField(
                          controller: fieldCtrl,
                          label: 'Field / Stream',
                          hint: 'e.g. Engineering, Medical, Commerce',
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        AppTextField(
                          controller: gradYearCtrl,
                          label: 'Graduation Year (Batch)',
                          hint: 'e.g. 2022',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXl),

                  const SectionHeader(title: 'Past Hostel Stay'),
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.cardPadding),
                    child: Column(
                      children: [
                        AppTextField(
                          controller: pastRoomCtrl,
                          label: 'Past Hostel Room Number',
                          hint: 'e.g. 204 or Wing A-12',
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        AppTextField(
                          controller: yearsStayedCtrl,
                          label: 'Years Stayed at Hostel',
                          hint: 'e.g. 2018 - 2022 (4 Years)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXl),

                  const SectionHeader(title: 'Current Career & Workplace'),
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.cardPadding),
                    child: Column(
                      children: [
                        AppTextField(
                          controller: companyCtrl,
                          label: 'Current Company / Hospital / Org',
                          hint: 'e.g. Google, TCS, Apollo Hospital',
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        AppTextField(
                          controller: designationCtrl,
                          label: 'Current Designation',
                          hint: 'e.g. Senior Software Engineer',
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: cityCtrl,
                                label: 'Current City',
                                hint: 'e.g. Bangalore',
                              ),
                            ),
                            const SizedBox(width: AppDimens.gapMd),
                            Expanded(
                              child: AppTextField(
                                controller: countryCtrl,
                                label: 'Country',
                                hint: 'e.g. India',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXl),

                  const SectionHeader(title: 'LinkedIn & Social'),
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.cardPadding),
                    child: Column(
                      children: [
                        AppTextField(
                          controller: linkedinCtrl,
                          label: 'LinkedIn Profile URL',
                          hint: 'https://linkedin.com/in/username',
                          prefixIcon: Icons.link_rounded,
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        AppTextField(
                          controller: bioCtrl,
                          label: 'Short Bio',
                          hint: 'Share a brief intro about yourself...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXl),

                  const SectionHeader(title: 'Mentorship for Hostel Juniors'),
                  AppCard(
                    padding: const EdgeInsets.all(AppDimens.cardPadding),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Offer Guidance to Juniors', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Current students staying at the hostel can reach out to you for career advice.'),
                          value: isMentor,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              isMentor = val;
                            });
                          },
                        ),
                        if (isMentor) ...[
                          const SizedBox(height: AppDimens.gapMd),
                          AppTextField(
                            controller: mentorshipTopicsCtrl,
                            label: 'Topics You Can Guide On',
                            hint: 'e.g. Resume Review, Tech Interviews, Core Engineering, Higher Studies',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapXl),

                  Obx(
                    () => AppButton(
                      label: 'Save Alumni Profile',
                      isLoading: controller.isSavingProfile.value,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
