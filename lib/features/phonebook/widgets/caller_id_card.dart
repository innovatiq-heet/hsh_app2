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

/// Modal bottom sheet presenting Truecaller-style campus Caller ID setup & status.
class CallerIdBottomSheet extends GetView<PhonebookController> {
  const CallerIdBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const CallerIdBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incoming Caller ID',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Campus Truecaller-style caller identification',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Reactive status card
              Obx(() {
                final s = controller.callerId.value;
                final busy = controller.isEnablingCallerId.value;
                final isIOS = GetPlatform.isIOS;
                final isWorking = s.isWorking;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isWorking ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isWorking ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isWorking ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isWorking ? const Color(0xFF059669) : const Color(0xFFD97706),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isWorking ? 'Caller ID Active' : 'Status: Inactive',
                                      style: TextStyle(
                                        color: isWorking ? const Color(0xFF059669) : const Color(0xFFD97706),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (isWorking)
                                TextButton(
                                  onPressed: controller.disableCallerId,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFE11D48),
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Disable',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isWorking
                                ? (isIOS
                                    ? 'Native CallKit is connected. Calls from students and parents show student name, room, and relation.'
                                    : 'Campus Caller ID is running. Incoming calls show student name, room or alumni relation on the popup.')
                                : 'Identify unknown calls from students and parents instantly before picking up.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!isWorking && s.supported) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : controller.enableCallerId,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.bolt_rounded, size: 20),
                          label: Text(
                            busy
                                ? 'Connecting...'
                                : (isIOS ? 'Open Settings & Enable' : 'Connect & Enable Caller ID'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],

                    if (isWorking && !isIOS && !s.overlayGranted) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.layers_outlined, size: 20, color: Color(0xFFD97706)),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Display Permission Needed',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Allow "Display over other apps" to see the visual heads-up card during calls.',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: controller.enableCallerId,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Grant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (!s.supported) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Campus Caller ID requires Android 10 or newer with Call Screening support.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ],
                );
              }),

              const SizedBox(height: 20),
              // Feature highlights
              _featureItem(
                Icons.security_rounded,
                'Instant Student Verification',
                'Instantly matches incoming numbers against the 1200+ offline student contacts.',
              ),
              const SizedBox(height: 10),
              _featureItem(
                Icons.room_rounded,
                'Room & Alumni Badges',
                'Know which room the student belongs to or whether they are alumni before picking up.',
              ),
              const SizedBox(height: 10),
              _featureItem(
                Icons.wifi_off_rounded,
                '100% Offline & Private',
                'Numbers are verified locally using your on-device hostel phonebook database.',
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _featureItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF0284C7)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

