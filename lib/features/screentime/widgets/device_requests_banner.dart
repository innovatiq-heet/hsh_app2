import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../controllers/screen_time_directory_controller.dart';

/// Opens a bottom sheet listing students waiting for admin/warden approval
/// after uninstalling/reinstalling HSH Connect or signing in on another phone.
Future<void> showDeviceRequestsSheet(
  BuildContext context, {
  required ScreenTimeDirectoryController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _DeviceRequestsSheet(controller: controller),
  );
}

/// Compact banner shown in the Warden Directory only when there is at least
/// one pending new-device or reinstall approval request.
class DeviceRequestsBanner extends StatelessWidget {
  final ScreenTimeDirectoryController controller;
  const DeviceRequestsBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.currentRole.value.canOperate) {
        return const SizedBox.shrink();
      }
      final requests = controller.pendingDeviceRequests;
      if (requests.isEmpty) return const SizedBox.shrink();

      final first = requests.first;
      final rawName = (first['student_name'] ?? 'Student').toString();
      final name = formatPersonName(rawName);
      final displayName = name.isNotEmpty ? name : rawName;
      final isReinstall =
          (first['attempt_type'] ?? '').toString() == 'reinstall';
      final model = (first['new_device_model'] ?? '').toString().trim();

      return Container(
        margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: () => showDeviceRequestsSheet(context, controller: controller),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cancelledRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phonelink_lock_rounded,
                  color: AppColors.cancelledRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Device Login Approvals',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cancelledRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${requests.length} Pending',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      requests.length == 1
                          ? '$displayName · ${isReinstall ? 'App reinstall' : 'New device'}${model.isNotEmpty ? ' ($model)' : ''}'
                          : '${requests.length} students waiting for login approval',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      );
    });
  }
}

class _DeviceRequestsSheet extends StatelessWidget {
  final ScreenTimeDirectoryController controller;
  const _DeviceRequestsSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Login Approvals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Students blocked after deleting the app or changing phones.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: Obx(() {
              final list = controller.pendingDeviceRequests;
              if (list.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending device approval requests.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                );
              }
              return ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, idx) {
                  final req = list[idx];
                  final id = int.tryParse((req['id'] ?? '').toString()) ?? 0;
                  final rawName = (req['student_name'] ?? 'Student').toString();
                  final name = formatPersonName(rawName);
                  final room = (req['room_number'] ?? '').toString().trim();
                  final attempt = (req['attempt_type'] ?? 'new_device').toString();
                  final oldModel = (req['old_device_model'] ?? '').toString().trim();
                  final newModel = (req['new_device_model'] ?? '').toString().trim();
                  final osVer = (req['new_os_version'] ?? '').toString().trim();

                  return PhonebookCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  room.isNotEmpty ? '${name.isNotEmpty ? name : rawName} · Rm $room' : (name.isNotEmpty ? name : rawName),
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: attempt == 'reinstall'
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  attempt == 'reinstall' ? 'Reinstall' : 'New Device',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: attempt == 'reinstall'
                                        ? const Color(0xFFB45309)
                                        : AppColors.cancelledRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'New phone: ${newModel.isNotEmpty ? newModel : 'Unknown'}${osVer.isNotEmpty ? ' ($osVer)' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                          ),
                          if (oldModel.isNotEmpty)
                            Text(
                              'Previously bound: $oldModel',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => controller.reviewDeviceRequest(id, approve: false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.cancelledRed,
                                    side: const BorderSide(color: AppColors.cancelledRed),
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => controller.reviewDeviceRequest(id, approve: true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.successGreen,
                                  ),
                                  child: const Text('Approve Device'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
