import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../common_enums/attendance_type.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import 'attendance_controller.dart';

/// Optional kiosk-style scan entry point. The scanned payload itself isn't
/// decoded by the server — a successful scan just flips `viaCode: true` on
/// the same mark-attendance call the manual button uses.
void showScanAttendanceSheet(BuildContext context, AttendanceType type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ScanAttendanceSheet(type: type),
  );
}

class _ScanAttendanceSheet extends StatefulWidget {
  final AttendanceType type;

  const _ScanAttendanceSheet({required this.type});

  @override
  State<_ScanAttendanceSheet> createState() => _ScanAttendanceSheetState();
}

class _ScanAttendanceSheetState extends State<_ScanAttendanceSheet> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimens.gapLg),
            child: Text(
              'Scan to mark ${widget.type.label}',
              style: AppTextStyles.subtitle,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    if (_handled || capture.barcodes.isEmpty) return;
                    _handled = true;
                    Get.find<AttendanceController>().mark(
                      widget.type,
                      viaCode: true,
                    );
                    Navigator.of(context).pop();
                  },
                ),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.secondary, width: 3),
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.gapLg),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
