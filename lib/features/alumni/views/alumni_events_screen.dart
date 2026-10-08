import '../../../core/constants/app_routes.dart';
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
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/gradient_header.dart';
import '../controllers/alumni_controller.dart';

class AlumniEventsScreen extends StatefulWidget {
  const AlumniEventsScreen({super.key});

  @override
  State<AlumniEventsScreen> createState() => _AlumniEventsScreenState();
}

class _AlumniEventsScreenState extends State<AlumniEventsScreen> {
  final AlumniController controller = Get.find<AlumniController>();

  @override
  void initState() {
    super.initState();
    controller.loadEvents();
  }

  void _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showRsvpSheet(BuildContext context, AlumniEventModel event) {
    String status = event.myRsvpStatus ?? 'attending';
    int guests = event.myGuestsCount;
    final notesCtrl = TextEditingController(text: event.myNotes ?? '');

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
                  Text(
                    'RSVP: ${event.title}',
                    style: AppTextStyles.headline.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Confirm your attendance for the reunion/event', style: AppTextStyles.bodySm),
                  const SizedBox(height: AppDimens.gapLg),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Going')),
                          selected: status == 'attending',
                          selectedColor: AppColors.successGreen,
                          labelStyle: TextStyle(
                            color: status == 'attending' ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) => setSheetState(() => status = 'attending'),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Maybe')),
                          selected: status == 'tentative',
                          selectedColor: AppColors.warningOrange,
                          labelStyle: TextStyle(
                            color: status == 'tentative' ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) => setSheetState(() => status = 'tentative'),
                        ),
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Can\'t Go')),
                          selected: status == 'declined',
                          selectedColor: AppColors.cancelledRed,
                          labelStyle: TextStyle(
                            color: status == 'declined' ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) => setSheetState(() => status = 'declined'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapLg),

                  if (status == 'attending') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bringing Guests / Batchmates?', style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: guests > 0 ? () => setSheetState(() => guests--) : null,
                            ),
                            Text('$guests', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w700)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setSheetState(() => guests++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                  ],

                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes / Dietary / Message',
                      hintText: 'e.g. Coming with 2019 batch group',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: AppDimens.gapLg),

                  AppButton(
                    label: 'Confirm RSVP',
                    onPressed: () async {
                      Get.back();
                      await controller.submitRsvp(event.id, status, guests: guests, notes: notesCtrl.text.trim());
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
      floatingActionButton: controller.isOperatorOrAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Event'),
              onPressed: () => Get.toNamed(Routes.operatorAlumni),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            overline: 'Hostel Gatherings',
            title: 'Reunions & Events',
            subtitle: 'Annual functions, sabhas & alumni meetups',
            expandedHeight: 180,
            leading: HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Get.back(),
            ),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              if (controller.isEventsLoading.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final events = controller.eventsList;
              if (events.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No Events Scheduled',
                    message: 'Upcoming reunions and sabha announcements will appear here.',
                  ),
                );
              }

              return AppRefreshIndicator(
                onRefresh: controller.loadEvents,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    AppDimens.gapLg,
                    AppDimens.screenPadding,
                    AppDimens.gapXxl,
                  ),
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppDimens.gapMd),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _buildEventCard(context, event);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, AlumniEventModel event) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.eventTypeDisplay,
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (event.totalAttending > 0)
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 14, color: AppColors.successGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${event.totalAttending} Attending',
                      style: AppTextStyles.caption.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapMd),
          Text(event.title, style: AppTextStyles.headline.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(event.description, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppDimens.gapMd),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppDimens.gapMd),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year} at ${event.eventDate.hour.toString().padLeft(2, '0')}:${event.eventDate.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(event.isOnline ? Icons.videocam_outlined : Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.venue,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.isOnline && event.meetingLink != null && event.meetingLink!.isNotEmpty)
                InkWell(
                  onTap: () => _openLink(event.meetingLink!),
                  child: Text(
                    'Join Link',
                    style: AppTextStyles.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.gapLg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    event.myRsvpStatus == 'attending'
                        ? Icons.check_circle_rounded
                        : (event.myRsvpStatus == 'declined' ? Icons.cancel_rounded : Icons.how_to_reg_rounded),
                    size: 18,
                    color: event.myRsvpStatus == 'attending'
                        ? AppColors.successGreen
                        : (event.myRsvpStatus == 'declined' ? AppColors.cancelledRed : AppColors.primary),
                  ),
                  label: Text(
                    event.myRsvpStatus != null
                        ? 'RSVP: ${event.myRsvpStatus!.toUpperCase()}'
                        : 'RSVP / Register',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showRsvpSheet(context, event),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
