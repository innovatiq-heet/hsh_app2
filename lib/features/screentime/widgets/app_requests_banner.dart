import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/string_formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../controllers/app_requests_host.dart';
import 'app_brand_icon.dart';

/// Opens the bottom sheet listing all pending app installation requests.
Future<void> showAppRequestsSheet(BuildContext context, {required AppRequestsHost host}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _AppRequestsSheet(host: host),
  );
}

/// Displays a sleek compact banner when there are pending app installation requests.
/// Tapping it opens a bottom sheet with the full list of request cards,
/// complete with student details, app title/description info, and approve/reject actions.
class AppRequestsBanner extends StatelessWidget {
  final AppRequestsHost host;
  final bool compact;

  const AppRequestsBanner({
    super.key,
    required this.host,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final requests = host.pendingAppRequests;
      if (requests.isEmpty) return const SizedBox.shrink();

      final firstReq = requests.first;
      final rawStudent = (firstReq['student_name'] ?? firstReq['studentName'] ?? firstReq['name'] ?? 'Student').toString();
      final formattedStudent = formatPersonName(rawStudent);
      final studentName = formattedStudent.isNotEmpty ? formattedStudent : rawStudent;
      final rawAppName = (firstReq['app_name'] ?? firstReq['appName'])?.toString().trim();
      final rawPkg = (firstReq['package_name'] ?? firstReq['packageName'])?.toString().trim() ?? '';
      final appName = (rawAppName != null && rawAppName.isNotEmpty) ? rawAppName : (rawPkg.isNotEmpty ? rawPkg : 'App');

      return Container(
        margin: const EdgeInsets.only(bottom: AppDimens.gapMd),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: () => showAppRequestsSheet(context, host: host),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.app_registration_rounded,
                  color: AppColors.primary,
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
                        const Text(
                          'App Requests',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.warningOrange,
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
                          ? '$studentName requested $appName'
                          : '${requests.length} students requesting approval to install apps',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: PhonebookTheme.blueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Review',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PhonebookTheme.blue,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: PhonebookTheme.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _AppRequestsSheet extends StatefulWidget {
  final AppRequestsHost host;

  const _AppRequestsSheet({required this.host});

  @override
  State<_AppRequestsSheet> createState() => _AppRequestsSheetState();
}

class _AppRequestsSheetState extends State<_AppRequestsSheet> {
  final Set<int> _busyIds = {};

  Future<void> _handleAction(int id, String action, {int durationMinutes = 15}) async {
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await widget.host.reviewAppRequest(id, action, durationMinutes: durationMinutes);
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }

  void _showAppDetailsDialog(
    BuildContext context, {
    int id = 0,
    required String appName,
    required String packageName,
    required String studentName,
    required String room,
    required String reason,
    String? createdAt,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: Row(
          children: [
            AppBrandIcon(packageName: packageName, appName: appName, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appName,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  if (packageName.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      packageName,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            _dialogDetailRow('Student', '$studentName ${room.isNotEmpty ? "• Room $room" : ""}'),
            if (createdAt != null && createdAt.isNotEmpty) ...[
              const SizedBox(height: 10),
              _dialogDetailRow('Requested', createdAt),
            ],
            const SizedBox(height: 12),
            const Text(
              'REASON / DESCRIPTION',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                reason.isNotEmpty ? reason : 'No specific reason provided.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: reason.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                  color: const Color(0xFF334155),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
          if (id > 0) ...[
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleAction(id, 'reject');
              },
              child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleAction(id, 'approve', durationMinutes: 15);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text('Allow (15m)', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _dialogDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final requests = widget.host.pendingAppRequests;

      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Single clean top drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.app_registration_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'App Requests',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Students requesting approval to install apps',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (requests.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${requests.length} Pending',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 18, color: Color(0xFFE2E8F0)),
              // Content
              Flexible(
                child: requests.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0FDF4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF16A34A),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'All Caught Up!',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'All student app installation requests have been reviewed.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 140,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                        itemCount: requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final req = requests[i];
                          final id = int.tryParse(
                                  (req['id'] ?? req['request_id'] ?? req['requestId'])?.toString() ?? '') ??
                              0;
                          final rawAppName = (req['app_name'] ?? req['appName'])?.toString().trim();
                          final rawPkg = (req['package_name'] ?? req['packageName'])?.toString().trim() ?? '';
                          final appName =
                              (rawAppName != null && rawAppName.isNotEmpty) ? rawAppName : (rawPkg.isNotEmpty ? rawPkg : 'App');
                          final pkg = rawPkg;
                          final rawStudentName =
                              (req['student_name'] ?? req['studentName'] ?? req['name'] ?? 'Student').toString();
                          final formattedStudentName = formatPersonName(rawStudentName);
                          final studentName = formattedStudentName.isNotEmpty ? formattedStudentName : rawStudentName;
                          final room = (req['room'] ?? req['room_num'] ?? '').toString();
                          final reason = (req['reason'] ?? '').toString();
                          final rawCreatedAt = (req['created_at'] ?? req['createdAt'])?.toString();
                          String? formattedTime;
                          if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
                            try {
                              formattedTime = DateFormatting.relativeTime(DateTime.parse(rawCreatedAt));
                            } catch (_) {}
                          }

                          final isBusy = _busyIds.contains(id);

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Student Header Row (tappable to view details)
                                InkWell(
                                  onTap: () => _showAppDetailsDialog(
                                    context,
                                    id: id,
                                    appName: appName,
                                    packageName: pkg,
                                    studentName: studentName,
                                    room: room,
                                    reason: reason,
                                    createdAt: formattedTime,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF0284C7),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              studentName,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              room.isNotEmpty ? 'Room $room' : 'Resident',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (formattedTime != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            formattedTime,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // 2. Action Buttons: Info, Reject, Allow (15m)
                                isBusy
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.2),
                                          ),
                                        ),
                                      )
                                    : Row(
                                        children: [
                                          // Info Button (shows App Title & Description in dialog)
                                          OutlinedButton.icon(
                                            onPressed: () => _showAppDetailsDialog(
                                              context,
                                              id: id,
                                              appName: appName,
                                              packageName: pkg,
                                              studentName: studentName,
                                              room: room,
                                              reason: reason,
                                              createdAt: formattedTime,
                                            ),
                                            icon: const Icon(Icons.info_outline_rounded, size: 16),
                                            label: const Text('Info'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF0284C7),
                                              side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.2),
                                              backgroundColor: const Color(0xFFF0F9FF),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                              visualDensity: VisualDensity.compact,
                                              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Reject Button
                                          Expanded(
                                            flex: 3,
                                            child: OutlinedButton.icon(
                                              onPressed: id > 0 ? () => _handleAction(id, 'reject') : null,
                                              icon: const Icon(Icons.close_rounded, size: 16),
                                              label: const Text('Reject'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                                                backgroundColor: const Color(0xFFFEF2F2),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(vertical: 9),
                                                visualDensity: VisualDensity.compact,
                                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Allow (15m) Button
                                          Expanded(
                                            flex: 4,
                                            child: ElevatedButton.icon(
                                              onPressed: id > 0
                                                  ? () => _handleAction(id, 'approve', durationMinutes: 15)
                                                  : null,
                                              icon: const Icon(Icons.check_rounded, size: 16),
                                              label: const Text('Allow (15m)'),
                                              style: ElevatedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor: const Color(0xFF16A34A),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(vertical: 9),
                                                visualDensity: VisualDensity.compact,
                                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
