import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/geofence/geofence_breach_event.dart';
import '../../../core/services/geofence_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/gradient_header.dart';
import '../../shared/widgets/section_header.dart';
import '../controllers/admin_geofence_controller.dart';

class AdminGeofenceScreen extends StatelessWidget {
  const AdminGeofenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AdminGeofenceController>()
        ? Get.find<AdminGeofenceController>()
        : Get.put(AdminGeofenceController());

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: CustomScrollView(
        slivers: [
          SliverGradientHeader(
            title: 'Campus Geofence',
            subtitle: 'Hostel boundary safety & night curfew controls',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: controller.loadData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final policy = controller.policy.value;
              final isCurfewNow = controller.isCurfewActiveNow;
              final active = controller.activeBreaches;
              final resolved = controller.resolvedLogs;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Live Curfew Status Banner
                    _buildCurfewStatusBanner(policy.isActive, isCurfewNow, policy.formatTimeRange()),
                    const SizedBox(height: 14),

                    // 2. Curfew Schedule & Configuration Card
                    _buildCurfewConfigCard(context, controller, policy),
                    const SizedBox(height: 18),

                    // 3. Active Breaches (Students Outside Campus)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionHeader(title: 'Active Breaches Outside Campus'),
                        if (active.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.cancelledRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${active.length} ALERT${active.length > 1 ? 'S' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (active.isEmpty)
                      _buildSafeStatusCard()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: active.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _buildBreachCard(context, controller, active[index]),
                      ),

                    const SizedBox(height: 22),

                    // 4. Campus Boundary Info
                    _buildCampusPerimeterCard(),
                    const SizedBox(height: 22),

                    // 5. Recent Movement Logs & Resolved Events
                    if (resolved.isNotEmpty) ...[
                      const SectionHeader(title: 'Resolved Movement History'),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: resolved.take(5).length,
                        separatorBuilder: (_, _) => const Divider(height: 12),
                        itemBuilder: (context, index) => _buildResolvedItem(resolved[index]),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildCurfewStatusBanner(bool isEnabled, bool isCurfewNow, String timeRange) {
    final Color bgColor = !isEnabled
        ? Colors.grey.shade200
        : (isCurfewNow ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4));
    final Color textColor = !isEnabled
        ? Colors.grey.shade700
        : (isCurfewNow ? AppColors.cancelledRed : const Color(0xFF15803D));
    final IconData icon = !isEnabled
        ? Icons.pause_circle_outline_rounded
        : (isCurfewNow ? Icons.nightlight_round : Icons.wb_sunny_rounded);

    final title = !isEnabled
        ? 'Geofence Tracking Paused'
        : (isCurfewNow ? 'Curfew Active Now — Boundary Enforced' : 'Daytime Hours — Curfew Inactive');

    final subtitle = !isEnabled
        ? 'Enable monitoring to detect boundary crossings.'
        : (isCurfewNow
            ? 'Any student crossing the perimeter triggers an immediate alert ($timeRange).'
            : 'Curfew will automatically arm tonight from $timeRange.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurfewConfigCard(BuildContext context, AdminGeofenceController controller, dynamic policy) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Curfew Schedule', style: AppTextStyles.title),
                      Text(
                        'Set night hours for geofence enforcement',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: policy.isActive,
                activeThumbColor: AppColors.primary,
                onChanged: controller.toggleGeofence,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  context,
                  label: 'Curfew Starts (Night)',
                  time: policy.startTime,
                  onSelected: (newTime) {
                    controller.updateCurfewTimes(newTime, policy.endTime);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePickerTile(
                  context,
                  label: 'Curfew Ends (Morning)',
                  time: policy.endTime,
                  onSelected: (newTime) {
                    controller.updateCurfewTimes(policy.startTime, newTime);
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Enforcement: lock the phone while outside (self-releasing on return)
          Row(
            children: [
              const Icon(Icons.phonelink_lock_rounded, color: AppColors.cancelledRed, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-lock phone when outside', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      'Locks on the student phone during a breach and unlocks when they return.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: policy.enforcePhoneLock,
                activeThumbColor: AppColors.cancelledRed,
                onChanged: policy.isActive ? controller.toggleLockOnBreach : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile(
    BuildContext context, {
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onSelected,
  }) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '$hour:$minute $period',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
          ),
          const SizedBox(height: 10),
          const Text(
            'All Students Safe Inside Campus',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'No outside perimeter breaches reported during curfew.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBreachCard(
    BuildContext context,
    AdminGeofenceController controller,
    GeofenceBreachEvent breach,
  ) {
    final timeStr = DateFormat('hh:mm a').format(breach.timestamp);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Student info & Alert badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.cancelledRed.withValues(alpha: 0.12),
                child: Text(
                  breach.studentName.isNotEmpty ? breach.studentName[0].toUpperCase() : 'S',
                  style: const TextStyle(color: AppColors.cancelledRed, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(breach.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'Room ${breach.room} • ID: ${breach.studentId}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cancelledRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.cancelledRed),
                    const SizedBox(width: 4),
                    Text(
                      breach.formattedDistance,
                      style: const TextStyle(
                        color: AppColors.cancelledRed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Breached campus perimeter at $timeStr', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),

          const Divider(height: 18),

          // Action Buttons Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Remote Lock Button
              ElevatedButton.icon(
                onPressed: () => controller.remoteLockStudentPhone(breach),
                icon: const Icon(Icons.lock_rounded, size: 14),
                label: const Text('Lock Phone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cancelledRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // 2. Call Student Button
              OutlinedButton.icon(
                onPressed: () => controller.callStudent(breach),
                icon: const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                label: const Text('Call Student', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // 3. Call Parent Button
              if (breach.parentPhone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => controller.callParent(breach),
                  icon: const Icon(Icons.family_restroom_rounded, size: 14, color: Colors.blueGrey),
                  label: const Text('Call Parent', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

              // 4. Send Warning Popup
              OutlinedButton.icon(
                onPressed: () => controller.sendCurfewWarning(breach),
                icon: const Icon(Icons.notification_important_rounded, size: 14, color: Colors.orange),
                label: const Text('Send Warning', style: TextStyle(fontSize: 11, color: Colors.orange)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // 5. Grant Gate Pass
              TextButton(
                onPressed: () => controller.grantTemporaryGatePass(breach, 1),
                child: const Text('Allow Gate Pass', style: TextStyle(fontSize: 11, color: Colors.green)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampusPerimeterCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Campus Geofence Boundary Map', style: AppTextStyles.title),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hari Saurabh Hostel boundary defined with ${CampusGeofenceService.campusPolygon.length} GPS perimeter coordinates (~22.55° N, 72.91° E). Checked on every student phone during curfew; a breach needs two consecutive GPS fixes outside.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedItem(GeofenceBreachEvent event) {
    String actionLabel = 'Resolved';
    Color actionColor = Colors.grey;

    switch (event.actionTaken) {
      case BreachActionStatus.phoneLocked:
        actionLabel = 'Phone Locked 🔒';
        actionColor = AppColors.cancelledRed;
        break;
      case BreachActionStatus.calledStudent:
        actionLabel = 'Student Called 📞';
        actionColor = AppColors.primary;
        break;
      case BreachActionStatus.calledParent:
        actionLabel = 'Parent Contacted 👨‍👩‍👧';
        actionColor = Colors.blueGrey;
        break;
      case BreachActionStatus.warningSent:
        actionLabel = 'Warning Sent ⚠️';
        actionColor = Colors.orange;
        break;
      case BreachActionStatus.gatePassGranted:
        actionLabel = 'Gate Pass Granted 🟢';
        actionColor = Colors.green;
        break;
      default:
        actionLabel = 'Dismissed';
        actionColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: actionColor.withValues(alpha: 0.12),
            child: Icon(Icons.history_rounded, size: 14, color: actionColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${DateFormat('hh:mm a').format(event.timestamp)} • ${event.formattedDistance}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              actionLabel,
              style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
