import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../../shared/widgets/student_contact_card.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';
import '../widgets/caller_id_card.dart';

/// Modern Campus Directory & Caller ID Console
class PhonebookScreen extends GetView<PhonebookController> {
  final bool showBackButton;
  const PhonebookScreen({super.key, this.showBackButton = true});

  static Color groupColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFF0284C7);
      case 'pavitra':
        return const Color(0xFF6366F1);
      case 'pulkit':
        return const Color(0xFFEA580C);
      case 'paramanand':
        return const Color(0xFF0D9488);
      case 'alumni':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF0284C7);
    }
  }

  static Color groupBgColor(String? group) {
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFFE0F2FE);
      case 'pavitra':
        return const Color(0xFFEEF2FF);
      case 'pulkit':
        return const Color(0xFFFFEDD5);
      case 'paramanand':
        return const Color(0xFFCCFBF1);
      case 'alumni':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFE0F2FE);
    }
  }

  void _showStudentContactDetails(
    BuildContext context,
    PhonebookStudent student,
  ) {
    final isAlumni = student.isAlumni;
    final gColor = isAlumni
        ? const Color(0xFF9333EA)
        : groupColor(student.groupName);
    final gBg = isAlumni
        ? const Color(0xFFF3E8FF)
        : groupBgColor(student.groupName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 18),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: gBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: gColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          student.name.isNotEmpty
                              ? student.name[0].toUpperCase()
                              : 'S',
                          style: TextStyle(
                            color: gColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
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
                                    student.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share_rounded, color: Color(0xFF0284C7), size: 20),
                                  tooltip: 'Share Profile',
                                  onPressed: () => controller.shareStudent(student),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (isAlumni)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE9D5FF),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.school_rounded,
                                          size: 12,
                                          color: Color(0xFF7E22CE),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Alumni / Left',
                                          style: TextStyle(
                                            color: Color(0xFF7E22CE),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (student.room != null &&
                                    student.room!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      'Room ${student.room}',
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (student.groupName != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: groupBgColor(student.groupName),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: groupColor(
                                          student.groupName,
                                        ).withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Text(
                                      student.groupName!,
                                      style: TextStyle(
                                        color: groupColor(student.groupName),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (student.bankCode != null &&
                                    student.bankCode!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      'Code: ${student.bankCode}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // 1. DATE OF BIRTH & CELEBRATION DETAILS
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: student.hasDob
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: student.hasDob
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: student.hasDob
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cake_rounded,
                            size: 20,
                            color: student.hasDob
                                ? const Color(0xFFD97706)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DATE OF BIRTH',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                student.hasDob
                                    ? '${student.formattedDob} ${student.ageText.isNotEmpty ? "(${student.ageText})" : ""}'
                                    : 'Not registered in directory',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: student.hasDob
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (student.hasDob)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Verified DOB',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. COMPLETE ADDRESS & CAMPUS LOCATION
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: student.hasAddress
                                    ? const Color(0xFFE0F2FE)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.home_rounded,
                                size: 18,
                                color: student.hasAddress
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'PERMANENT ADDRESS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const Spacer(),
                            if (student.hasAddress)
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                tooltip: 'Copy Address',
                                onPressed: () => controller.copyToClipboard(
                                  student.displayAddress,
                                  'Student Address',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          student.displayAddress,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: student.hasAddress ? FontWeight.w500 : FontWeight.w400,
                            color: student.hasAddress ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                            fontStyle: student.hasAddress ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                        if (student.floor != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              student.floor == 0 ? 'Ground Floor' : 'Floor ${student.floor}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. IDENTIFIERS & ACADEMIC INFO
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STUDENT IDENTITY & ACADEMICS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _infoBlock('Aadhar Card', student.maskedAadhar, onCopy: student.aadhar != null ? () => controller.copyToClipboard(student.aadhar!, 'Aadhar') : null),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _infoBlock('Bank / Student ID', student.studentId.isNotEmpty ? student.studentId : 'N/A', onCopy: () => controller.copyToClipboard(student.studentId, 'Student ID')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _infoBlock('Wing / Group', student.groupName ?? 'Hostel', subtitle: student.room != null ? 'Room ${student.room}' : 'No Room'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _infoBlock('Admission Status', student.status?.toUpperCase() ?? (isAlumni ? 'ALUMNI' : 'ACTIVE'), isHighlight: !isAlumni),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3.5 PARENTS & GUARDIAN DETAILS
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PARENTS & GUARDIAN DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _infoBlock(
                                'Father Name',
                                student.fatherName ?? 'Not Provided',
                                subtitle: student.fatherPhone != null ? 'Ph: ${student.fatherPhone}' : null,
                                onCopy: student.fatherName != null ? () => controller.copyToClipboard(student.fatherName!, 'Father Name') : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _infoBlock(
                                'Mother Name',
                                student.motherName ?? 'Not Provided',
                                subtitle: student.motherPhone != null ? 'Ph: ${student.motherPhone}' : null,
                                onCopy: student.motherName != null ? () => controller.copyToClipboard(student.motherName!, 'Mother Name') : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. REGISTERED CONTACT DIRECTORY
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'CONTACT DIRECTORY (STUDENT & FAMILY)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Family contacts if available
                  if (student.fatherPhone != null && student.fatherPhone!.isNotEmpty)
                    _buildPhoneRow(
                      context,
                      phone: student.fatherPhone!,
                      label: student.fatherName != null ? 'Father (${student.fatherName})' : 'Father Contact',
                      icon: Icons.family_restroom_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                    ),

                  if (student.motherPhone != null && student.motherPhone!.isNotEmpty)
                    _buildPhoneRow(
                      context,
                      phone: student.motherPhone!,
                      label: student.motherName != null ? 'Mother (${student.motherName})' : 'Mother Contact',
                      icon: Icons.family_restroom_rounded,
                      iconBg: const Color(0xFFFCE7F3),
                      iconColor: const Color(0xFFDB2777),
                    ),

                  if (student.whatsappNumber != null && student.whatsappNumber!.isNotEmpty)
                    _buildPhoneRow(
                      context,
                      phone: student.whatsappNumber!,
                      label: 'Dedicated WhatsApp',
                      icon: Icons.chat_rounded,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                    ),

                  // All student phones from directory
                  ...student.phones.map((p) {
                    final isWhatsApp = p.label.toLowerCase().contains('whatsapp');
                    final isFather = p.label.toLowerCase().contains('father');
                    final isMother = p.label.toLowerCase().contains('mother');
                    if (isFather || isMother) return const SizedBox.shrink();

                    return _buildPhoneRow(
                      context,
                      phone: p.phone,
                      label: p.label,
                      icon: isWhatsApp ? Icons.chat_rounded : Icons.phone_rounded,
                      iconBg: isWhatsApp ? const Color(0xFFECFDF5) : const Color(0xFFE0F2FE),
                      iconColor: isWhatsApp ? const Color(0xFF059669) : const Color(0xFF0284C7),
                    );
                  }),

                  if (student.email != null && student.email!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.email_rounded, size: 18, color: Color(0xFF0D9488)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              student.email!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                            tooltip: 'Copy Email',
                            onPressed: () => controller.copyToClipboard(student.email!, 'Email'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Primary Share Details Action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => controller.shareStudent(student),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Complete Student Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: student.primaryPhone != 'No Phone'
                              ? () {
                                  Navigator.pop(ctx);
                                  controller.makeCall(student.primaryPhone);
                                }
                              : null,
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call Student'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: student.primaryPhone != 'No Phone'
                              ? () {
                                  Navigator.pop(ctx);
                                  controller.openWhatsApp(
                                    student.whatsappNumber?.isNotEmpty == true
                                        ? student.whatsappNumber!
                                        : student.primaryPhone,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Get.toNamed(
                          Routes.studentScreenTime,
                          arguments: {
                            'name': student.name,
                            'room': student.room ?? '',
                          },
                        );
                      },
                      icon: const Icon(Icons.phone_android_rounded, size: 18),
                      label: const Text('View Individual Screen Time'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoBlock(String label, String value, {String? subtitle, VoidCallback? onCopy, bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              if (onCopy != null)
                InkWell(
                  onTap: onCopy,
                  child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isHighlight ? const Color(0xFF047857) : const Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneRow(
    BuildContext context, {
    required String phone,
    required String label,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phone,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
            tooltip: 'Copy Number',
            onPressed: () => controller.copyToClipboard(phone, label),
          ),
          IconButton(
            icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF059669)),
            tooltip: 'WhatsApp',
            onPressed: () {
              Navigator.pop(context);
              controller.openWhatsApp(phone);
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, size: 18, color: Color(0xFF0284C7)),
            tooltip: 'Call Phone',
            onPressed: () {
              Navigator.pop(context);
              controller.makeCall(phone);
            },
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag Handle & Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                children: [
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter & Sort Students',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Refine by wings, floors, residence, and records',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Obx(() {
                        if (controller.activeFilterCount == 0) return const SizedBox.shrink();
                        return TextButton(
                          onPressed: () {
                            controller.resetAllFilters();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text(
                            'Reset All',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Obx(() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. WING / GROUP
                      _filterSectionHeader('HOSTEL WING / GROUP', Icons.apartment_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PhonebookController.hshGroups.map((g) {
                          final sel = controller.selectedGroup.value == g;
                          final isAlumni = g.toLowerCase() == 'alumni';
                          final color = isAlumni ? const Color(0xFF9333EA) : const Color(0xFF0284C7);
                          return FilterChip(
                            label: Text(g),
                            selected: sel,
                            selectedColor: color,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: sel ? Colors.white : const Color(0xFF334155),
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: sel ? color : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onSelected: (v) => controller.selectGroup(g),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 2. FLOOR SELECTOR
                      _filterSectionHeader('HOSTEL FLOOR', Icons.layers_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PhonebookController.floorOptions.map((f) {
                          final sel = controller.selectedFloor.value == f;
                          return FilterChip(
                            label: Text(f),
                            selected: sel,
                            selectedColor: const Color(0xFF0284C7),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: sel ? Colors.white : const Color(0xFF334155),
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: sel ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onSelected: (v) => controller.selectFloor(f),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 3. RESIDENCE STATUS
                      _filterSectionHeader('RESIDENCE STATUS', Icons.badge_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PhonebookController.statusOptions.map((s) {
                          final sel = controller.selectedStatus.value == s;
                          return FilterChip(
                            label: Text(s),
                            selected: sel,
                            selectedColor: const Color(0xFF059669),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: sel ? Colors.white : const Color(0xFF334155),
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: sel ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onSelected: (v) => controller.selectStatus(s),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // 4. ATTRIBUTES & PROFILE DATA
                      _filterSectionHeader('PROFILE ATTRIBUTES & RECORDS', Icons.check_circle_outline_rounded),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _toggleRow(
                              icon: Icons.cake_outlined,
                              iconColor: const Color(0xFFD97706),
                              title: 'Has Date of Birth (DOB)',
                              subtitle: 'Show students with registered birthday info',
                              value: controller.onlyWithDob.value,
                              onChanged: controller.toggleOnlyWithDob,
                            ),
                            const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                            _toggleRow(
                              icon: Icons.family_restroom_rounded,
                              iconColor: const Color(0xFF059669),
                              title: 'Has Parent Contact Phone',
                              subtitle: 'Show students with Father or Mother numbers',
                              value: controller.onlyWithParents.value,
                              onChanged: controller.toggleOnlyWithParents,
                            ),
                            const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                            _toggleRow(
                              icon: Icons.chat_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: 'Has Dedicated WhatsApp Number',
                              subtitle: 'Show students with verified WhatsApp details',
                              value: controller.onlyWithWhatsApp.value,
                              onChanged: controller.toggleOnlyWithWhatsApp,
                            ),
                            const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                            _toggleRow(
                              icon: Icons.home_rounded,
                              iconColor: const Color(0xFF0284C7),
                              title: 'Has Permanent Address',
                              subtitle: 'Show students with hometown/permanent address',
                              value: controller.onlyWithAddress.value,
                              onChanged: controller.toggleOnlyWithAddress,
                            ),
                            const Divider(height: 1, indent: 52, color: Color(0xFFE2E8F0)),
                            _toggleRow(
                              icon: Icons.fingerprint_rounded,
                              iconColor: const Color(0xFF6366F1),
                              title: 'Has Aadhar Number',
                              subtitle: 'Show students with registered 12-digit Aadhar',
                              value: controller.onlyWithAadhar.value,
                              onChanged: controller.toggleOnlyWithAadhar,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. SORT ORDER
                      _filterSectionHeader('SORT STUDENTS BY', Icons.sort_by_alpha_rounded),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PhonebookController.sortOptions.map((s) {
                          final sel = controller.selectedSort.value == s;
                          return ChoiceChip(
                            label: Text(s),
                            selected: sel,
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: TextStyle(
                              color: sel ? Colors.white : const Color(0xFF334155),
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: sel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onSelected: (v) => controller.selectSort(s),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }),
              ),
            ),

            // Bottom Sticky Action Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Obx(() {
                      final count = controller.students.length;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Apply Filters & Show ($count Students)',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF0284C7)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF0284C7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeFilterPill({required String label, required VoidCallback onDismiss}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0369A1),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 13, color: Color(0xFF0369A1)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        controller.checkFirstTimeCallerId(() {
          if (context.mounted) {
            CallerIdBottomSheet.show(context);
          }
        });
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: Obx(() {
          if (!controller.isSelectionMode.value) return const SizedBox.shrink();
          final count = controller.selectedCount;
          final allSelected = count == controller.students.length && count > 0;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: controller.toggleSelectAll,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Icon(
                              allSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: const Color(0xFF0284C7),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              allSelected ? 'Deselect All' : 'Select All',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count Selected',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0284C7)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Exit Selection',
                        onPressed: controller.exitSelectionMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Share to Any App (System Share Sheet)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: count > 0 ? controller.shareSelectedStudents : null,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Share directly to WhatsApp
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: count > 0 ? controller.shareSelectedToWhatsApp : null,
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Copy
                      IconButton.filledTonal(
                        onPressed: count > 0 ? controller.copySelectedDetails : null,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy to Clipboard',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        body: RefreshIndicator(
          onRefresh: () => controller.syncNow(),
          color: const Color(0xFF0284C7),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PhonebookHeaderDelegate(
                  controller: controller,
                  topPadding: MediaQuery.of(context).padding.top,
                  showBackButton: showBackButton,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search & Filter Launcher Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: controller.searchController,
                                onChanged: controller.onSearchChanged,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search student, room, parent, aadhar...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF0284C7),
                                    size: 22,
                                  ),
                                  suffixIcon: Obx(() {
                                    if (controller.isSearching.value) {
                                      return const Padding(
                                        padding: EdgeInsets.all(13),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      );
                                    }
                                    if (controller.searchText.value.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      onPressed: controller.clearSearch,
                                    );
                                  }),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Obx(() {
                            final count = controller.activeFilterCount;
                            return Material(
                              color: count > 0 ? const Color(0xFF0284C7) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              elevation: count > 0 ? 3 : 1,
                              shadowColor: count > 0 ? const Color(0xFF0284C7).withValues(alpha: 0.3) : Colors.black12,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showFilterBottomSheet(context),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: count > 0 ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        size: 20,
                                        color: count > 0 ? Colors.white : const Color(0xFF0284C7),
                                      ),
                                      if (count > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: Color(0xFF0284C7),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Group / Wing Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Obx(() {
                          return Row(
                            children: PhonebookController.hshGroups.map((g) {
                              final isSelected = controller.selectedGroup.value == g;
                              final isAlumniChip = g.toLowerCase() == 'alumni';
                              final color = isAlumniChip
                                  ? const Color(0xFF9333EA)
                                  : const Color(0xFF0284C7);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => controller.selectGroup(g),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected ? color : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected ? color : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.25),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isAlumniChip) ...[
                                            Icon(
                                              Icons.school_rounded,
                                              size: 14,
                                              color: isSelected ? Colors.white : const Color(0xFF9333EA),
                                            ),
                                            const SizedBox(width: 5),
                                          ],
                                          Text(
                                            g,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFF475569),
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),

                      // Active Filters & Quick Filter Chips
                      Obx(() {
                        final activeCount = controller.activeFilterCount;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // Full filter sheet launcher
                              ActionChip(
                                avatar: Icon(
                                  Icons.filter_list_rounded,
                                  size: 14,
                                  color: activeCount > 0 ? Colors.white : const Color(0xFF0284C7),
                                ),
                                label: Text(
                                  activeCount > 0 ? 'All Filters ($activeCount)' : 'All Filters',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: activeCount > 0 ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                backgroundColor: activeCount > 0 ? const Color(0xFF0284C7) : Colors.white,
                                side: BorderSide(
                                  color: activeCount > 0 ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                ),
                                onPressed: () => _showFilterBottomSheet(context),
                              ),
                              const SizedBox(width: 6),

                              // If filters are active, display dismissible active chips
                              if (controller.selectedFloor.value != 'All') ...[
                                _activeFilterPill(
                                  label: 'Floor: ${controller.selectedFloor.value}',
                                  onDismiss: controller.clearFloor,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (controller.selectedStatus.value != 'All') ...[
                                _activeFilterPill(
                                  label: controller.selectedStatus.value,
                                  onDismiss: controller.clearStatus,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (controller.onlyWithDob.value) ...[
                                _activeFilterPill(
                                  label: '🎂 DOB Only',
                                  onDismiss: controller.clearDob,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (controller.onlyWithParents.value) ...[
                                _activeFilterPill(
                                  label: '👨‍👩‍👦 Parents Only',
                                  onDismiss: controller.clearParents,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (controller.onlyWithWhatsApp.value) ...[
                                _activeFilterPill(
                                  label: '💬 WhatsApp Only',
                                  onDismiss: controller.clearWhatsApp,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (controller.onlyWithAddress.value) ...[
                                _activeFilterPill(
                                  label: '🏠 Address Only',
                                  onDismiss: controller.clearAddress,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (controller.onlyWithAadhar.value) ...[
                                _activeFilterPill(
                                  label: '🆔 Aadhar Only',
                                  onDismiss: controller.clearAadhar,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (controller.selectedSort.value != 'Name (A-Z)') ...[
                                _activeFilterPill(
                                  label: 'Sort: ${controller.selectedSort.value}',
                                  onDismiss: controller.clearSort,
                                ),
                                const SizedBox(width: 6),
                              ],

                              // When active filters exist, show a prominent Clear All pill
                              if (activeCount > 0) ...[
                                ActionChip(
                                  avatar: const Icon(Icons.clear_all_rounded, size: 14, color: Colors.redAccent),
                                  label: const Text(
                                    'Clear All',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  side: const BorderSide(color: Color(0xFFFECACA)),
                                  onPressed: controller.resetAllFilters,
                                ),
                              ],

                              // If no active secondary filters, show quick action chips
                              if (activeCount == 0) ...[
                                ActionChip(
                                  avatar: const Icon(Icons.layers_rounded, size: 14, color: Color(0xFF64748B)),
                                  label: const Text('Floor ▾', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  onPressed: () => _showFilterBottomSheet(context),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.cake_outlined, size: 14, color: Color(0xFF64748B)),
                                  label: const Text('🎂 Birthday', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  onPressed: () => controller.toggleOnlyWithDob(true),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.family_restroom_rounded, size: 14, color: Color(0xFF64748B)),
                                  label: const Text('👨‍👩‍👦 Parents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  onPressed: () => controller.toggleOnlyWithParents(true),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF64748B)),
                                  label: const Text('💬 WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  onPressed: () => controller.toggleOnlyWithWhatsApp(true),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  avatar: const Icon(Icons.sort_by_alpha_rounded, size: 14, color: Color(0xFF64748B)),
                                  label: const Text('Sort ▾', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  onPressed: () => _showFilterBottomSheet(context),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
// Section title with live count
                      Obx(() {
                        final count = controller.students.length;
                        return Row(
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
                            Text(
                              'STUDENT CONTACTS ($count)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Student List Sliver
              Obx(() {
                if (controller.isLoading.value) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  );
                }

                final list = controller.students;
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 20,
                      ),
                      child: EmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'No student contacts found',
                        message:
                            controller.searchText.value.isNotEmpty ||
                                controller.activeFilterCount > 0
                            ? 'Try clearing active filters or modifying your search query.'
                            : 'Tap Sync to download contacts from the live campus directory.',
                        actionLabel: controller.activeFilterCount > 0 ? 'Clear Filters' : 'Sync Now',
                        onAction: controller.activeFilterCount > 0 ? controller.resetAllFilters : () => controller.syncNow(),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = list[index];
                      final isSelected = controller.isStudentSelected(student.id);
                      final isSelectionMode = controller.isSelectionMode.value;

                      final card = _StudentPhonebookCard(
                        student: student,
                        isSelected: isSelected,
                        isSelectionMode: isSelectionMode,
                        onTap: () {
                          if (isSelectionMode) {
                            controller.toggleSelectStudent(student.id);
                          } else {
                            _showStudentContactDetails(context, student);
                          }
                        },
                        onLongPress: () {
                          if (!isSelectionMode) {
                            controller.startSelectionMode(student.id);
                          } else {
                            controller.toggleSelectStudent(student.id);
                          }
                        },
                        onCall: (phone) => controller.makeCall(phone),
                        onWhatsApp: (phone) => controller.openWhatsApp(phone),
                        onShare: () => controller.shareStudent(student),
                      );

                      if (index < 8) {
                        return StaggeredSlideFade(
                          index: index,
                          duration: const Duration(milliseconds: 280),
                          slideOffset: 12.0,
                          child: card,
                        );
                      }
                      return card;
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible shrinking deep navy header with luminous arcs, sync action and status pills.
class _PhonebookHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PhonebookController controller;
  final double topPadding;
  final bool showBackButton;

  _PhonebookHeaderDelegate({
    required this.controller,
    required this.topPadding,
    this.showBackButton = true,
  });

  @override
  double get minExtent => topPadding + 60.0;

  @override
  double get maxExtent => topPadding + 172.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular(
      (28.0 * (1.0 - progress)).clamp(0.0, 28.0),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF03192E),
            Color(0xFF032B4F),
            Color(0xFF025A8D),
            Color(0xFF0369A1),
          ],
          stops: [0.0, 0.38, 0.75, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        boxShadow: progress > 0.25
            ? [
                BoxShadow(
                  color: const Color(
                    0xFF03192E,
                  ).withValues(alpha: 0.22 * progress),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _HeaderOrbPainter()),

            // Top pinned navigation bar (Back button, Collapsed title, Sync button)
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  if (showBackButton && Navigator.canPop(context)) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Get.back(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Pinned title
                  Expanded(
                    child: Opacity(
                      opacity: collapsedTitleOpacity,
                      child: const Text(
                        'Student Phonebook',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Incoming Caller ID button (connect / status)
                  Obx(() {
                    final status = controller.callerId.value;
                    final isWorking = status.isWorking;
                    final isSupported = status.supported;

                    final Color bg = isWorking
                        ? const Color(0xFF10B981).withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.16);
                    final Color border = isWorking
                        ? const Color(0xFF34D399).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.25);
                    final Color iconColor = isWorking
                        ? const Color(0xFF34D399)
                        : (isSupported ? Colors.white : Colors.white60);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => CallerIdBottomSheet.show(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Tooltip(
                          message: isWorking
                              ? 'Caller ID: Active'
                              : (isSupported
                                  ? 'Caller ID: Inactive (Tap to connect)'
                                  : 'Caller ID unavailable'),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: bg,
                              shape: BoxShape.circle,
                              border: Border.all(color: border, width: 1),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  isWorking
                                      ? Icons.phone_in_talk_rounded
                                      : Icons.phone_callback_rounded,
                                  color: iconColor,
                                  size: 20,
                                ),
                                Positioned(
                                  top: 9,
                                  right: 9,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isWorking
                                          ? const Color(0xFF10B981)
                                          : (isSupported
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF94A3B8)),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF032B4F),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),

                  // Sync directory button
                  Obx(() {
                    final isSyncing = controller.isSyncing.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isSyncing ? null : () => controller.syncNow(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: isSyncing
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.sync_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Hero expanded text & status pills
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Opacity(
                opacity: expandedOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'STUDENT DIRECTORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Hostel Phonebook',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(() {
                      final sync = controller.lastSync.value;
                      final count = controller.totalCachedCount.value;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_alt_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  '$count Verified Contacts',
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, size: 13, color: Colors.white70),
                                const SizedBox(width: 5),
                                Text(
                                  sync != null ? dateFormat.format(sync) : 'Never synced',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _HeaderOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.86, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Student contact card in directory view, using shared [StudentContactCard].
class _StudentPhonebookCard extends StatelessWidget {
  final PhonebookStudent student;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<String> onCall;
  final ValueChanged<String> onWhatsApp;
  final VoidCallback? onShare;

  const _StudentPhonebookCard({
    required this.student,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    this.onLongPress,
    required this.onCall,
    required this.onWhatsApp,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return StudentContactCard(
      name: student.name,
      room: student.room,
      groupName: student.groupName,
      bankCode: student.bankCode,
      dobText: student.hasDob
          ? '${student.formattedDob}${student.ageText.isNotEmpty ? " (${student.ageText})" : ""}'
          : null,
      primaryPhone: student.primaryPhone,
      alternatePhonesCount:
          student.phones.length > 1 ? student.phones.length - 1 : 0,
      whatsappNumber: student.whatsappNumber,
      isAlumni: student.isAlumni,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      onTap: onTap,
      onLongPress: onLongPress,
      onCall: onCall,
      onWhatsApp: onWhatsApp,
      onShare: onShare,
    );
  }
}

