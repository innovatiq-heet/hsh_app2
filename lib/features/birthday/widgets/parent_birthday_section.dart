import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import '../../../core/utils/student_photo.dart';
import '../../shared/widgets/student_avatar.dart';
import '../../shared/widgets/student_contact_card.dart';
import '../controllers/admin_birthday_controller.dart';
import '../models/parent_birthday.dart';

/// "Parents' birthdays" on the Today / Tomorrow tabs: fathers and mothers whose
/// own birthday it is, from the phonebook on this phone. Call, or WhatsApp
/// with the active Father / Mother template (opens this phone's WhatsApp).
class ParentBirthdaySection extends StatelessWidget {
  final AdminBirthdayController controller;
  final List<ParentBirthday> parents;
  final bool isToday;

  /// Shows a "Send all via bot" bar (when no student card already offers Send All).
  final bool showSendAll;

  const ParentBirthdaySection({
    super.key,
    required this.controller,
    required this.parents,
    required this.isToday,
    this.showSendAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "PARENTS' BIRTHDAYS (${parents.length})",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'FATHER & MOTHER',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (showSendAll)
          _SendAllBar(
            controller: controller,
            count: parents.where((p) => !p.alreadySent).length,
          ),
        for (final p in parents)
          ParentBirthdayCard(
            controller: controller,
            parent: p,
            isToday: isToday,
          ),
      ],
    );
  }
}

class ParentBirthdayCard extends StatelessWidget {
  final AdminBirthdayController controller;
  final ParentBirthday parent;
  final bool isToday;

  const ParentBirthdayCard({
    super.key,
    required this.controller,
    required this.parent,
    required this.isToday,
  });

  static const _fatherColor = Color(0xFF0369A1);
  static const _motherColor = Color(0xFFDB2777);

  @override
  Widget build(BuildContext context) {
    final p = parent;
    final accent = p.isFather ? _fatherColor : _motherColor;
    final hasPhone = p.phone.replaceAll(RegExp(r'\D'), '').length >= 6;
    final group = p.groupName?.trim() ?? '';
    final room = (p.room ?? '').trim();
    final showRoom =
        !p.isAlumni && room.isNotEmpty && room.toLowerCase() != 'n/a';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentAvatar(
                name: p.parentName,
                aadhar: p.studentAadhar,
                bankCode: p.bankCode,
                photoOf: p.isFather ? PhotoOf.father : PhotoOf.mother,
                size: 46,
                background: accent.withValues(alpha: 0.12),
                child: Icon(
                  p.isFather ? Icons.man_rounded : Icons.woman_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.parentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.relationLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                icon: Icons.cake_rounded,
                text: p.turning != null
                    ? (isToday
                          ? 'Turns ${p.turning} today'
                          : 'Turns ${p.turning} tomorrow')
                    : (isToday ? 'Birthday today' : 'Birthday tomorrow'),
                color: const Color(0xFFD97706),
              ),
              if (p.isAlumni)
                const _Chip(
                  icon: Icons.school_rounded,
                  text: 'Alumni',
                  color: Color(0xFF9333EA),
                )
              else if (group.isNotEmpty)
                _Chip(
                  icon: Icons.groups_rounded,
                  text: group,
                  color: StudentContactCard.groupColor(group),
                ),
              if (showRoom)
                _Chip(
                  icon: Icons.meeting_room_rounded,
                  text: 'Room $room',
                  color: const Color(0xFF475569),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isToday && controller.parentBirthdaysFromServer.value)
            _withBot(context, p, accent, hasPhone)
          else
            Row(
              children: [
                Expanded(
                  child: _ActionIcon(
                    tooltip: 'Call',
                    background: hasPhone
                        ? accent.withValues(alpha: 0.12)
                        : const Color(0xFFE2E8F0),
                    onTap: hasPhone
                        ? () => controller.callPhone(p.phone)
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.call_rounded,
                          size: 18,
                          color: hasPhone ? accent : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Call',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: hasPhone ? accent : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionIcon(
                    tooltip: 'Wish on WhatsApp',
                    background: hasPhone
                        ? const Color(0xFF25D366)
                        : const Color(0xFFE2E8F0),
                    onTap: hasPhone
                        ? () => controller.wishParentViaWhatsApp(p)
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.whatsapp,
                          size: 18,
                          color: hasPhone
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Wish',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: hasPhone
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Today's card from the server list: Call and WhatsApp (this phone) as
/// icons, and **Send via bot** (server WhatsApp, the active Father / Mother
/// template), which turns into "Sent" once wished.
Widget _withBot(
  BuildContext context,
  ParentBirthday p,
  Color accent,
  bool hasPhone,
) {
  final controller = Get.find<AdminBirthdayController>();
  return Obx(() {
    final sending = controller.sendingParentKeys.contains(p.key);
    final current =
        controller.parentBirthdaysToday.firstWhereOrNull(
          (x) => x.key == p.key,
        ) ??
        p;
    final sent = current.alreadySent;
    final canBot = hasPhone && controller.canWishParentViaBot(current);
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: _ActionIcon(
            tooltip: 'Call',
            background: hasPhone
                ? accent.withValues(alpha: 0.12)
                : const Color(0xFFE2E8F0),
            onTap: hasPhone ? () => controller.callPhone(p.phone) : null,
            child: Icon(
              Icons.call_rounded,
              size: 19,
              color: hasPhone ? accent : const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: _ActionIcon(
            tooltip: "Wish from this phone's WhatsApp",
            background: hasPhone
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFE2E8F0),
            onTap: hasPhone ? () => controller.wishParentViaWhatsApp(p) : null,
            child: FaIcon(
              FontAwesomeIcons.whatsapp,
              size: 19,
              color: hasPhone
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionIcon(
            tooltip: sent
                ? 'Already wished today'
                : 'Send through the WhatsApp bot',
            background: sent
                ? const Color(0xFFECFDF5)
                : (canBot ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
            onTap: canBot && !sending
                ? () => controller.wishParentViaBot(current)
                : null,
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        sent
                            ? Icons.check_circle_rounded
                            : Icons.smart_toy_rounded,
                        size: 18,
                        color: sent
                            ? const Color(0xFF059669)
                            : (canBot ? Colors.white : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sent ? 'Wished today' : 'Send via bot',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: sent
                              ? const Color(0xFF059669)
                              : (canBot
                                    ? Colors.white
                                    : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  });
}

/// "Send all via bot" for a day with only parents celebrating: runs the same
/// Send All (which includes parents when the setting is on).
class _SendAllBar extends StatelessWidget {
  final AdminBirthdayController controller;
  final int count;

  const _SendAllBar({required this.controller, required this.count});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = controller.isTriggering.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 0
                    ? 'Every parent here has been wished today.'
                    : 'Wish all $count through the WhatsApp bot.',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: busy || count == 0
                  ? null
                  : () => controller.triggerAllToday(),
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send all'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Chip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final String tooltip;
  final Widget child;
  final Color background;
  final VoidCallback? onTap;

  const _ActionIcon({
    required this.tooltip,
    required this.child,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}
