import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/alumni/alumni_models.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_refresh_indicator.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../controllers/alumni_controller.dart';

class AlumniAdminHubScreen extends StatefulWidget {
  const AlumniAdminHubScreen({super.key});

  @override
  State<AlumniAdminHubScreen> createState() => _AlumniAdminHubScreenState();
}

class _AlumniAdminHubScreenState extends State<AlumniAdminHubScreen>
    with SingleTickerProviderStateMixin {
  final AlumniController controller = Get.find<AlumniController>();
  late TabController _tabController;
  final TextEditingController _profileSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    controller.loadAdminStats();
    controller.loadEvents();
    controller.loadNews();
    controller.loadAdminProfiles();
    controller.loadJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      controller.loadAdminStats(),
      controller.loadEvents(),
      controller.loadNews(),
      controller.loadAdminProfiles(),
      controller.loadJobs(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverGradientHeader(
              overline: 'Operator Console',
              title: 'Alumni Network Admin',
              subtitle: 'Manage events, RSVPs, giving back & profile verifications',
              expandedHeight: 220,
              leading: HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Get.back(),
              ),
              actions: [
                HeaderIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'Student Hub View',
                  onPressed: () => Get.toNamed(Routes.alumniHub),
                ),
              ],
              child: Obx(() {
                final stats = controller.adminStats.value;
                return Row(
                  children: [
                    Expanded(
                      child: HeaderPill(
                        icon: Icons.school_rounded,
                        label: '${stats.totalAlumni} Alumni',
                      ),
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    Expanded(
                      child: HeaderPill(
                        icon: Icons.verified_user_rounded,
                        label: '${stats.verifiedAlumni} Verified',
                      ),
                    ),
                    const SizedBox(width: AppDimens.gapSm),
                    Expanded(
                      child: HeaderPill(
                        icon: Icons.event_available_rounded,
                        label: '${stats.upcomingEvents} Events',
                      ),
                    ),
                  ],
                );
              }),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTextStyles.subtitle.copyWith(fontSize: 14),
                  tabs: const [
                    Tab(icon: Icon(Icons.event_note_rounded), text: 'Events & RSVPs'),
                    Tab(icon: Icon(Icons.volunteer_activism_rounded), text: 'Giving Back / News'),
                    Tab(icon: Icon(Icons.how_to_reg_rounded), text: 'Alumni Verification'),
                    // Tab(icon: Icon(Icons.work_outline_rounded), text: 'Job Moderation'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEventsTab(),
            _buildNewsTab(),
            _buildVerificationTab(),
            // _buildJobsTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: EVENTS & RSVPs
  // ==========================================================================
  Widget _buildEventsTab() {
    return AppRefreshIndicator(
      onRefresh: _refreshAll,
      child: Obx(() {
        final events = controller.eventsList;
        return ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(title: 'Reunions & Scheduled Events'),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showCreateEventDialog(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.gapMd),
            if (events.isEmpty)
              const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No Events Created',
                message: 'Tap "+ New Event" to schedule an alumni reunion, annual sabha, or webinar.',
              )
            else
              for (final event in events) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppDimens.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event.eventTypeDisplay,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.gapSm),
                          if (event.isOnline)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.successGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ONLINE',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.cancelledRed),
                            tooltip: 'Delete Event',
                            onPressed: () => _confirmDeleteEvent(event),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(event.title, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${DateFormat('EEE, d MMM yyyy, h:mm a').format(event.eventDate)}',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        'Venue: ${event.venue}',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(event.description, style: AppTextStyles.caption),
                      ],
                      const SizedBox(height: AppDimens.gapMd),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${event.totalAttending} Confirmed Attendees',
                                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.list_alt_rounded, size: 16),
                            label: const Text('View RSVPs'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showEventRsvpsSheet(context, event),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.gapMd),
              ],
          ],
        );
      }),
    );
  }

  // ==========================================================================
  // TAB 2: GIVING BACK & NEWS
  // ==========================================================================
  Widget _buildNewsTab() {
    return AppRefreshIndicator(
      onRefresh: _refreshAll,
      child: Obx(() {
        final newsList = controller.newsList;
        return ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(title: 'News & Voluntary Initiatives'),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showCreateNewsDialog(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.gapMd),
            if (newsList.isEmpty)
              const EmptyState(
                icon: Icons.campaign_outlined,
                title: 'No News or Initiatives',
                message: 'Post renovation updates, hostel achievements, or contribution campaigns.',
              )
            else
              for (final news in newsList) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppDimens.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBadge(icon: Icons.volunteer_activism_rounded, color: const Color(0xFFEC4899), size: 36),
                          const SizedBox(width: AppDimens.gapSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(news.title, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  '${news.categoryDisplay} • ${DateFormat('d MMM yyyy').format(news.createdAt)}',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.cancelledRed),
                            tooltip: 'Delete Item',
                            onPressed: () => _confirmDeleteNews(news),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.gapSm),
                      Text(news.content, style: AppTextStyles.bodySm),
                      if (news.targetAmount != null && news.targetAmount! > 0) ...[
                        const SizedBox(height: AppDimens.gapMd),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Raised: ₹${NumberFormat('#,##,###').format(news.raisedAmount)}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Target: ₹${NumberFormat('#,##,###').format(news.targetAmount)}',
                              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: news.progressPercentage,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFEC4899)),
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapSm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text('Update Raised Funds'),
                            onPressed: () => _showUpdateFundsDialog(context, news),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.gapMd),
              ],
          ],
        );
      }),
    );
  }

  // ==========================================================================
  // TAB 3: ALUMNI VERIFICATION & MENTOR DESK
  // ==========================================================================
  Widget _buildVerificationTab() {
    return AppRefreshIndicator(
      onRefresh: _refreshAll,
      child: Obx(() {
        final profiles = controller.adminProfiles;
        return ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            const SectionHeader(title: 'Alumni Profile Verification & Badges'),
            const SizedBox(height: AppDimens.gapSm),
            TextField(
              controller: _profileSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by student name, code, room, company...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _profileSearchCtrl.clear();
                    controller.loadAdminProfiles();
                  },
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (term) => controller.loadAdminProfiles(search: term.trim()),
            ),
            const SizedBox(height: AppDimens.gapMd),
            if (controller.isAdminProfilesLoading.value)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (profiles.isEmpty)
              const EmptyState(
                icon: Icons.person_search_rounded,
                title: 'No Profiles Found',
                message: 'No alumni profiles matching the search criteria.',
              )
            else
              for (final profile in profiles) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppDimens.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              profile.initials,
                              style: AppTextStyles.subtitle.copyWith(
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
                                        profile.name,
                                        style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (profile.isVerified)
                                      const Icon(Icons.verified_rounded, size: 18, color: AppColors.primary),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${profile.batchLabel} • Room stayed: ${profile.pastRoomNumber.isNotEmpty ? profile.pastRoomNumber : 'N/A'}',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                                if (profile.currentRoleLine.isNotEmpty)
                                  Text(profile.currentRoleLine, style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ChoiceChip(
                            label: Text(profile.isVerified ? 'Verified Alumnus' : 'Unverified'),
                            selected: profile.isVerified,
                            selectedColor: AppColors.primarySoft,
                            labelStyle: TextStyle(
                              color: profile.isVerified ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              controller.adminToggleVerification(profile.studentId, val);
                            },
                          ),
                          ChoiceChip(
                            label: Text(profile.isMentor ? 'Active Mentor' : 'Not Mentor'),
                            selected: profile.isMentor,
                            selectedColor: AppColors.successGreen.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: profile.isMentor ? AppColors.successGreen : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              controller.adminToggleMentor(profile.studentId, val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.gapMd),
              ],
          ],
        );
      }),
    );
  }

  // ==========================================================================
  // TAB 4: JOB MODERATION (Temporarily disabled)
  // ==========================================================================
  /*
  Widget _buildJobsTab() {
    return AppRefreshIndicator(
      onRefresh: _refreshAll,
      child: Obx(() {
        final jobs = controller.jobsList;
        return ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            const SectionHeader(title: 'Alumni Job Postings & Moderation'),
            const SizedBox(height: AppDimens.gapMd),
            if (jobs.isEmpty)
              const EmptyState(
                icon: Icons.work_off_rounded,
                title: 'No Job Openings',
                message: 'No job postings currently active in the community board.',
              )
            else
              for (final job in jobs) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppDimens.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconBadge(icon: Icons.work_rounded, color: AppColors.successGreen, size: 40),
                          const SizedBox(width: AppDimens.gapSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job.title, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                                Text('${job.company} • ${job.location}', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.cancelledRed),
                            tooltip: 'Delete Job',
                            onPressed: () async {
                              await controller.deleteJob(job.id);
                              await controller.loadAdminStats();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(job.description, style: AppTextStyles.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppDimens.gapSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Type: ${job.jobTypeDisplay}', style: AppTextStyles.caption),
                          TextButton.icon(
                            icon: const Icon(Icons.toggle_on_rounded, color: AppColors.primary),
                            label: const Text('Toggle Status'),
                            onPressed: () => controller.adminToggleJob(job.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.gapMd),
              ],
          ],
        );
      }),
    );
  }
  */

  // ==========================================================================
  // DIALOGS & BOTTOM SHEETS
  // ==========================================================================

  void _showCreateEventDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String eventType = 'reunion';
    bool isOnline = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Create Alumni Event / Sabha', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Event Title *', hintText: 'e.g. 2026 Annual Grand Reunion'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: eventType,
                    decoration: const InputDecoration(labelText: 'Event Type'),
                    items: const [
                      DropdownMenuItem(value: 'reunion', child: Text('Reunion')),
                      DropdownMenuItem(value: 'annual_sabha', child: Text('Annual Sabha')),
                      DropdownMenuItem(value: 'meetup', child: Text('City Meetup')),
                      DropdownMenuItem(value: 'networking', child: Text('Career Networking')),
                      DropdownMenuItem(value: 'webinar', child: Text('Online Webinar')),
                    ],
                    onChanged: (val) => setDialogState(() => eventType = val ?? 'reunion'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date & Time'),
                    subtitle: Text(DateFormat('EEE, d MMM yyyy, h:mm a').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  TextField(
                    controller: venueCtrl,
                    decoration: const InputDecoration(labelText: 'Venue *', hintText: 'Hostel Main Hall / City Hotel'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Online Event / Zoom?'),
                    value: isOnline,
                    onChanged: (val) => setDialogState(() => isOnline = val),
                  ),
                  if (isOnline)
                    TextField(
                      controller: linkCtrl,
                      decoration: const InputDecoration(labelText: 'Meeting URL', hintText: 'https://zoom.us/j/...'),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description / Details'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || venueCtrl.text.trim().isEmpty) {
                    Get.snackbar('Required', 'Please enter Title and Venue');
                    return;
                  }
                  Get.back();
                  await controller.adminCreateEvent({
                    'title': titleCtrl.text.trim(),
                    'event_type': eventType,
                    'event_date': selectedDate.toIso8601String(),
                    'venue': venueCtrl.text.trim(),
                    'is_online': isOnline,
                    'meeting_link': linkCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                  });
                },
                child: const Text('Publish Event'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEventRsvpsSheet(BuildContext context, AlumniEventModel event) {
    controller.loadEventRsvps(event.id);

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RSVP Guest List', style: AppTextStyles.headline.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(event.title, style: AppTextStyles.bodySm.copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Get.back()),
              ],
            ),
            const Divider(),
            Expanded(
              child: Obx(() {
                if (controller.isRsvpsLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rsvps = controller.currentEventRsvps;
                if (rsvps.isEmpty) {
                  return const Center(child: Text('No RSVPs received yet for this event.', style: TextStyle(color: AppColors.textSecondary)));
                }

                int totalGuests = 0;
                for (final r in rsvps) {
                  if (r.status == 'attending') totalGuests += (1 + r.guestsCount);
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('Total Responses: ${rsvps.length}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                          Text('Expected Heads: $totalGuests', style: AppTextStyles.caption.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rsvps.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = rsvps[index];
                          Color statusColor = AppColors.successGreen;
                          if (r.status == 'tentative') statusColor = AppColors.warningOrange;
                          if (r.status == 'declined') statusColor = AppColors.cancelledRed;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withValues(alpha: 0.15),
                              child: Text(
                                r.studentName.isNotEmpty ? r.studentName[0].toUpperCase() : '?',
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Code: ${r.studentCode} • Room: ${r.roomNumber.isNotEmpty ? r.roomNumber : 'N/A'}${r.guestsCount > 0 ? ' • Guests: +${r.guestsCount}' : ''}${r.notes.isNotEmpty ? '\nNotes: ${r.notes}' : ''}',
                              style: AppTextStyles.caption,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.statusDisplay,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showCreateNewsDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    String category = 'news';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Post Hostel News / Initiative', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. New Reading Hall Renovation'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'news', child: Text('General News')),
                      DropdownMenuItem(value: 'renovation', child: Text('Hostel Renovation')),
                      DropdownMenuItem(value: 'initiative', child: Text('Voluntary Contribution')),
                      DropdownMenuItem(value: 'achievement', child: Text('Hostel Achievement')),
                    ],
                    onChanged: (val) => setDialogState(() => category = val ?? 'news'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Details / Description *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Contribution Target (₹)',
                      hintText: 'e.g. 500000 (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(labelText: 'Initiative Link / Form', hintText: 'https://...'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                    Get.snackbar('Required', 'Please enter Title and Content');
                    return;
                  }
                  Get.back();
                  await controller.adminCreateNews({
                    'title': titleCtrl.text.trim(),
                    'category': category,
                    'content': contentCtrl.text.trim(),
                    'target_amount': targetCtrl.text.trim().isNotEmpty ? double.tryParse(targetCtrl.text.trim()) : null,
                    'initiative_link': linkCtrl.text.trim(),
                  });
                },
                child: const Text('Publish Post'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateFundsDialog(BuildContext context, HostelNewsModel news) {
    final raisedCtrl = TextEditingController(text: news.raisedAmount.toInt().toString());

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Raised Amount: ${news.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: raisedCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Raised Amount (₹)', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final amount = double.tryParse(raisedCtrl.text.trim()) ?? news.raisedAmount;
              await controller.adminUpdateNews(news.id, {
                'title': news.title,
                'category': news.category,
                'content': news.content,
                'target_amount': news.targetAmount,
                'raised_amount': amount,
                'initiative_link': news.initiativeLink,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEvent(AlumniEventModel event) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Event?'),
        content: Text('Are you sure you want to delete "${event.title}" and its RSVPs?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cancelledRed, foregroundColor: Colors.white),
            onPressed: () {
              Get.back();
              controller.adminDeleteEvent(event.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNews(HostelNewsModel news) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Post?'),
        content: Text('Are you sure you want to delete "${news.title}"?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cancelledRed, foregroundColor: Colors.white),
            onPressed: () {
              Get.back();
              controller.adminDeleteNews(news.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
