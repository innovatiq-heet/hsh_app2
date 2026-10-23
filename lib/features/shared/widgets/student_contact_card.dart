import 'package:flutter/material.dart';

/// Reusable executive student contact card featuring the signature
/// organic corner wave, squircle avatar, light metadata chips,
/// and quick-action communication controls.
class StudentContactCard extends StatelessWidget {
  final String name;
  final String? room;
  final String? groupName;
  final String? bankCode;
  final String? dobText;
  final String primaryPhone;
  final int alternatePhonesCount;
  final String? whatsappNumber;
  final bool isAlumni;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onCall;
  final ValueChanged<String>? onWhatsApp;
  final VoidCallback? onShare;
  final Widget? customSubtitle;
  final Widget? statusPill;
  final List<Widget>? extraChips;
  final EdgeInsetsGeometry? margin;

  const StudentContactCard({
    super.key,
    required this.name,
    this.room,
    this.groupName,
    this.bankCode,
    this.dobText,
    required this.primaryPhone,
    this.alternatePhonesCount = 0,
    this.whatsappNumber,
    this.isAlumni = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    this.onLongPress,
    this.onCall,
    this.onWhatsApp,
    this.onShare,
    this.customSubtitle,
    this.statusPill,
    this.extraChips,
    this.margin,
  });

  /// Group accent color
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

  /// Group soft background tint
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

  /// Pastel wave tint matching the celebrant signature palette
  static Color waveColor(String? group, {bool isAlumni = false}) {
    if (isAlumni) return const Color(0xFFE9D5FF);
    switch (group?.toLowerCase().trim()) {
      case 'param':
        return const Color(0xFFBAE6FD);
      case 'pavitra':
        return const Color(0xFFC7D2FE);
      case 'pulkit':
        return const Color(0xFFFED7AA);
      case 'paramanand':
        return const Color(0xFF99F6E4);
      case 'alumni':
        return const Color(0xFFE9D5FF);
      default:
        return const Color(0xFFBAE6FD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gColor = isAlumni ? const Color(0xFF9333EA) : groupColor(groupName);
    final gBg = isAlumni ? const Color(0xFFF3E8FF) : groupBgColor(groupName);
    final wave = waveColor(groupName, isAlumni: isAlumni);

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
          width: isSelected ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF0284C7).withValues(alpha: 0.1)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Bottom-right organic corner wave (celebrant signature)
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(110, 75),
                  painter: CornerWavePainter(
                    color: wave.withValues(alpha: 0.55),
                  ),
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Identity Row: Squircle Avatar + Name/Subtitle + Status Pill
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Squircle avatar
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelectionMode
                                    ? (isSelected
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFFF1F5F9))
                                    : gBg,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelectionMode
                                      ? (isSelected
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFFCBD5E1))
                                      : gColor.withValues(alpha: 0.25),
                                  width: isSelectionMode && isSelected ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: isSelectionMode
                                  ? Icon(
                                      isSelected
                                          ? Icons.check_rounded
                                          : Icons.circle_outlined,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF94A3B8),
                                      size: 22,
                                    )
                                  : Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'S',
                                      style: TextStyle(
                                        color: gColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 21,
                                      ),
                                    ),
                            ),
                            if (!isSelectionMode)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: gColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isAlumni
                                        ? Icons.school_rounded
                                        : Icons.person_rounded,
                                    color: Colors.white,
                                    size: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // Name + Subtitle inline
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              customSubtitle ??
                                  Text(
                                    isAlumni
                                        ? 'Alumni Student'
                                        : (room != null && room!.isNotEmpty
                                            ? 'Room $room • ${groupName ?? "Resident"}'
                                            : (groupName ?? 'Registered Student')),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: gColor,
                                      height: 1.25,
                                    ),
                                  ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Top-right status pill
                        statusPill ??
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: gBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: gColor.withValues(alpha: 0.3),
                                  width: 1.1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: gColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isAlumni ? 'Alumni' : (groupName ?? 'Active'),
                                    style: TextStyle(
                                      color: gColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 2. Metadata Light Chips (Celebrant Chip Style)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4.5,
                      children: [
                        if (!isAlumni && room != null && room!.isNotEmpty)
                          CelebrantLightChip(
                            icon: Icons.meeting_room_rounded,
                            text: 'Room $room',
                            bgColor: const Color(0xFFF1F5F9),
                            borderColor: const Color(0xFFE2E8F0),
                            textColor: const Color(0xFF334155),
                          ),
                        if (bankCode != null && bankCode!.isNotEmpty)
                          CelebrantLightChip(
                            icon: Icons.tag_rounded,
                            text: 'ID: $bankCode',
                            bgColor: const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFFE2E8F0),
                            textColor: const Color(0xFF475569),
                          ),
                        if (dobText != null && dobText!.isNotEmpty)
                          CelebrantLightChip(
                            icon: Icons.cake_outlined,
                            text: dobText!,
                            bgColor: const Color(0xFFFFFBEB),
                            borderColor: const Color(0xFFFDE68A),
                            textColor: const Color(0xFFD97706),
                          ),
                        ...?extraChips,
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // 3. Primary phone & quick communication action row
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Primary phone block
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.phone_rounded,
                                    size: 14,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        primaryPhone,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (alternatePhonesCount > 0)
                                        Text(
                                          '+$alternatePhonesCount more contact${alternatePhonesCount > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Quick action buttons: WhatsApp + Call
                          if (primaryPhone != 'No Phone' &&
                              primaryPhone.isNotEmpty) ...[
                            if (onWhatsApp != null)
                              _CardActionButton(
                                icon: Icons.chat_rounded,
                                iconColor: const Color(0xFF059669),
                                bgColor: const Color(0xFFECFDF5),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
                                tooltip: 'Chat on WhatsApp',
                                onTap: () => onWhatsApp!(
                                  whatsappNumber?.isNotEmpty == true
                                      ? whatsappNumber!
                                      : primaryPhone,
                                ),
                              ),
                            if (onCall != null) ...[
                              const SizedBox(width: 6),
                              _CardActionButton(
                                icon: Icons.phone_rounded,
                                iconColor: const Color(0xFF0284C7),
                                bgColor: const Color(0xFFE0F2FE),
                                border: Border.all(
                                  color: const Color(0xFFBAE6FD),
                                ),
                                tooltip: 'Call Student ($primaryPhone)',
                                onTap: () => onCall!(primaryPhone),
                              ),
                            ],
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'No Phone',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modular rounded chip used across celebrant and student contact cards
class CelebrantLightChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const CelebrantLightChip({
    super.key,
    required this.icon,
    required this.text,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Border? border;
  final String tooltip;
  final VoidCallback onTap;

  const _CardActionButton({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.border,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// Organic corner wave painter matching the operator home & celebrant card signature
class CornerWavePainter extends CustomPainter {
  final Color color;

  const CornerWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.72,
      size.width * 0.55,
      size.height * 0.48,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.22,
      size.width,
      0,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerWavePainter oldDelegate) =>
      oldDelegate.color != color;
}
