import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/storage/session_store.dart';

/// Gates logout behind a one-time 6-digit warden override code for monitored
/// student accounts so logging out cannot silently disable Device Admin or
/// stop screen-time / geofence enforcement.
class WardenLogoutGuard {
  WardenLogoutGuard._();

  static bool requiresWardenCode(SessionStore store) {
    final s = store.currentSession;
    if (s == null || s.token.isEmpty) return false;
    return s.role == UserRole.student && !s.isAlumni;
  }

  /// Shows a warden-code prompt when [requiresWardenCode] is true, verifies it
  /// via `/screen-time/removal-codes/verify` (`purpose: 'logout'`), and performs
  /// [SessionStore.logout] only when authorised (or when no student guard applies).
  static Future<bool> confirmAndLogout(BuildContext? context) async {
    if (!Get.isRegistered<SessionStore>()) return false;
    final store = Get.find<SessionStore>();
    if (!requiresWardenCode(store)) {
      await store.logout();
      return true;
    }

    if (context == null || !context.mounted) return false;
    final authorized = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _WardenLogoutDialog(),
    );
    if (authorized != true) return false;
    await store.logout();
    return true;
  }
}

class _WardenLogoutDialog extends StatefulWidget {
  const _WardenLogoutDialog();

  @override
  State<_WardenLogoutDialog> createState() => _WardenLogoutDialogState();
}

class _WardenLogoutDialogState extends State<_WardenLogoutDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _ctrl.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code from your warden');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final valid = await ScreenTimeRepository().verifyRemovalCode(
      code,
      purpose: 'logout',
    );
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Wrong or expired code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
      ),
      title: const Text('Warden code required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter a one-time 6-digit code from your warden to log out of student monitoring.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimens.gapMd),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofocus: true,
            style: AppTextStyles.headline.copyWith(letterSpacing: 6),
            decoration: InputDecoration(
              counterText: '',
              hintText: '6-digit code',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cancelledRed,
            foregroundColor: Colors.white,
          ),
          child: Text(_busy ? 'Checking…' : 'Verify & Log out'),
        ),
      ],
    );
  }
}
