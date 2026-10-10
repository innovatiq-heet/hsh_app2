import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/phonebook_controller.dart';

/// "Know who's calling" — Truecaller-style campus caller identification.
class CallerIdCard extends GetView<PhonebookController> {
  const CallerIdCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = controller.callerId.value;
      final busy = controller.isEnablingCallerId.value;
      final isIOS = GetPlatform.isIOS;

      if (!s.supported) {
        if (isIOS) {
          return _shell(
            icon: Icons.phone_in_talk_rounded,
            iconColor: const Color(0xFF0284C7),
            bgTint: const Color(0xFFE0F2FE),
            statusBadge: _badge('iOS CallKit', const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
            title: 'Know who\'s calling',
            body: 'Identify student and parent calls directly on the native incoming call screen.',
            trailing: _actionButton(
              label: 'Open Settings',
              icon: Icons.settings_rounded,
              isLoading: busy,
              onPressed: controller.enableCallerId,
            ),
          );
        }
        return _shell(
          icon: Icons.phone_disabled_rounded,
          iconColor: const Color(0xFF94A3B8),
          bgTint: const Color(0xFFF1F5F9),
          statusBadge: _badge('Unavailable', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
          title: 'Caller ID not available',
          body: 'Requires Android 10 or newer with Call Screening support.',
        );
      }

      if (s.isWorking) {
        return _shell(
          icon: Icons.phone_callback_rounded,
          iconColor: const Color(0xFF059669),
          bgTint: const Color(0xFFD1FAE5),
          statusBadge: _badge('Active', const Color(0xFF059669), const Color(0xFFD1FAE5)),
          title: 'Campus Caller ID is active',
          body: isIOS
              ? 'Incoming calls display "HSH · Name · Room/Alumni · Relation" on the call screen.'
              : 'A heads-up identification card pops up showing student name, room or alumni status, and relation.',
          trailing: TextButton(
            onPressed: controller.disableCallerId,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE11D48),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            child: const Text('Turn off'),
          ),
          footer: !isIOS && !s.overlayGranted
              ? _hint(
                  'Popup blocked — grant "Display over other apps" to see the visual card during calls. Heads-up notifications are still active.',
                  action: 'Grant Access',
                  onTap: controller.enableCallerId,
                )
              : null,
        );
      }

      // Not working yet
      final body = isIOS
          ? (s.iosState == 'disabled'
              ? 'Turn on "HSH App" under Settings → Phone → Call Blocking & Identification.'
              : 'Identify incoming calls from students and parents directly on screen.')
          : 'Instant caller ID — identify student name, room or alumni relation before answering.';

      return _shell(
        icon: Icons.phone_in_talk_rounded,
        iconColor: const Color(0xFF0284C7),
        bgTint: const Color(0xFFE0F2FE),
        statusBadge: _badge('Inactive', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
        title: 'Incoming Caller ID',
        body: body,
        trailing: _actionButton(
          label: isIOS ? 'Open Settings' : 'Enable',
          icon: isIOS ? Icons.settings_rounded : Icons.check_rounded,
          isLoading: busy,
          onPressed: controller.enableCallerId,
        ),
      );
    });
  }

  Widget _badge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    if (isLoading) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        elevation: 0,
      ),
    );
  }

  Widget _shell({
    required IconData icon,
    required Color iconColor,
    required Color bgTint,
    required Widget statusBadge,
    required String title,
    required String body,
    Widget? trailing,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        statusBadge,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _hint(String text, {required String action, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: const Color(0xFFD97706),
            ),
            child: Text(
              action,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
