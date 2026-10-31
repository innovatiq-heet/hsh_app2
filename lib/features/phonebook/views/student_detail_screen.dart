import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badge.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';
import '../services/phone_number_normalizer.dart';

/// Full-screen profile of one phonebook student: navy header, quick actions,
/// hostel / personal / family details and every contact number with its own
/// copy, WhatsApp, message and call actions.
class StudentDetailScreen extends StatelessWidget {
  final PhonebookStudent student;
  const StudentDetailScreen({super.key, required this.student});

  static const Color _googleBlue = Color(0xFF1A73E8);

  PhonebookController get _c => Get.find<PhonebookController>();

  bool get _hasPhone => student.primaryPhone != 'No Phone';

  static String _digitsOf(String? raw) =>
      PhoneNumberNormalizer.normalize(raw) ??
      (raw ?? '').replaceAll(RegExp(r'\D'), '');

  /// True when the dedicated WhatsApp number equals one of the student's own
  /// mobile numbers (parents' numbers don't count), so it is not listed twice.
  bool get _whatsappSameAsMobile {
    final wa = _digitsOf(student.whatsappNumber);
    if (wa.isEmpty) return false;
    return student.phones.any((p) {
      final label = p.label.toLowerCase();
      if (label.contains('father') || label.contains('mother')) return false;
      return _digitsOf(p.phone) == wa;
    });
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StudentDetailHeaderDelegate(
                student: student,
                topPadding: MediaQuery.of(context).padding.top,
                contentWidth: MediaQuery.of(context).size.width - 40,
                onBack: () => Navigator.of(context).pop(),
                onCopyCode: () =>
                    _c.copyToClipboard(student.bankCode ?? '', 'Student code'),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapLg,
                AppDimens.screenPadding,
                AppDimens.gapXl + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList.list(
                children: [
                  if (_hasPhone || _has(student.email) || _studentNumbers.isNotEmpty) ...[
                    _studentContactCard(),
                    const SizedBox(height: AppDimens.gapMd),
                  ],
                  _hostelCard(),
                  const SizedBox(height: AppDimens.gapMd),
                  _personalCard(),
                  if (_has(student.fatherName) || _has(student.motherName)) ...[
                    const SizedBox(height: AppDimens.gapMd),
                    _familyCard(),
                  ],
                  if (_familyContacts().isNotEmpty) ...[
                    const SizedBox(height: AppDimens.gapLg),
                    const SectionHeader(title: 'Family contacts'),
                    ..._familyContacts(),
                  ],
                  const SizedBox(height: AppDimens.gapMd),
                  AppButton(
                    label: 'Share complete details',
                    icon: Icons.ios_share_rounded,
                    onPressed: () => _c.shareStudent(student),
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  AppButton(
                    label: 'View screen time',
                    icon: Icons.timelapse_rounded,
                    variant: AppButtonVariant.outline,
                    onPressed: () => Get.toNamed(
                      Routes.studentScreenTime,
                      arguments: {
                        'name': student.name,
                        'room': student.room ?? '',
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  String get _whatsappTarget =>
      _has(student.whatsappNumber) ? student.whatsappNumber! : student.primaryPhone;

  /// The student's own mobile number(s) (dedicated WhatsApp included when it
  /// differs from the mobile) as (number, label) pairs.
  List<({String phone, String label})> get _studentNumbers {
    final out = <({String phone, String label})>[];
    for (final p in student.phones) {
      final label = p.label.toLowerCase();
      if (label.contains('father') || label.contains('mother')) continue;
      out.add((phone: p.phone, label: p.label));
    }
    if (_has(student.whatsappNumber) && !_whatsappSameAsMobile) {
      out.add((phone: student.whatsappNumber!, label: 'WhatsApp'));
    }
    return out;
  }

  /// One card on top: the student's numbers and email (tap to copy) and the
  /// round Call / WhatsApp / Message / Gmail actions.
  Widget _studentContactCard() {
    return _CollapsibleContactCard(
      lines: [
        for (final n in _studentNumbers)
            _CopyLine(
              icon: n.label.toLowerCase().contains('whatsapp')
                  ? Icons.chat_rounded
                  : Icons.smartphone_rounded,
              color: n.label.toLowerCase().contains('whatsapp')
                  ? AppColors.successGreen
                  : AppColors.primary,
              text: n.phone,
              caption: n.label,
              onTap: () => _c.copyToClipboard(n.phone, n.label),
            ),
          if (_has(student.email))
            _CopyLine(
              icon: Icons.mail_rounded,
              color: AppColors.cancelledRed,
              text: student.email!,
              caption: 'Email',
              onTap: () => _c.copyToClipboard(student.email!, 'Email'),
            ),
      ],
      actions: Row(
            children: [
              if (_hasPhone) ...[
                _QuickAction(
                  icon: const Icon(Icons.call_rounded, size: 22),
                  label: 'Call',
                  color: AppColors.primary,
                  onTap: () => _c.makeCall(student.primaryPhone),
                ),
                _QuickAction(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 22),
                  label: 'WhatsApp',
                  color: AppColors.successGreen,
                  onTap: () => _c.openWhatsApp(_whatsappTarget),
                ),
                _QuickAction(
                  icon: const Icon(Icons.message_rounded, size: 22),
                  label: 'Message',
                  color: _googleBlue,
                  onTap: () => _c.sendSms(student.primaryPhone),
                ),
              ],
              if (_has(student.email))
                _QuickAction(
                  icon: const GmailIcon(size: 24),
                  label: 'Gmail',
                  color: AppColors.cancelledRed,
                  tinted: false,
                  onTap: () => _c.openEmail(student.email!),
                ),
            ],
          ),
    );
  }

  // ---------------------------------------------------------------- details

  Widget _hostelCard() {
    final isAlumni = student.isAlumni;
    final floor = student.floor;
    final status = student.status?.toUpperCase() ?? (isAlumni ? 'ALUMNI' : 'ACTIVE');
    return _DetailCard(
      title: 'Hostel',
      children: [
        _DetailRow(
          icon: Icons.meeting_room_rounded,
          label: 'Room',
          value: _has(student.room) ? student.room! : 'Not allotted',
          muted: !_has(student.room),
        ),
        if (floor != null)
          _DetailRow(
            icon: Icons.stairs_rounded,
            label: 'Floor',
            value: floor == 0 ? 'Ground floor' : 'Floor $floor',
          ),
        _DetailRow(
          icon: Icons.apartment_rounded,
          label: 'Wing / group',
          value: student.groupName ?? 'Hostel',
        ),
        _DetailRow(
          icon: Icons.verified_user_rounded,
          label: 'Status',
          valueWidget: StatusBadge(
            label: status,
            color: isAlumni ? const Color(0xFF9333EA) : AppColors.successGreen,
          ),
        ),
        if (student.studentId.isNotEmpty)
          _DetailRow(
            icon: Icons.badge_rounded,
            label: 'Student ID',
            value: student.studentId,
            onCopy: () => _c.copyToClipboard(student.studentId, 'Student ID'),
          ),
        if (_has(student.aadhar))
          _DetailRow(
            icon: Icons.fingerprint_rounded,
            label: 'Aadhar',
            value: student.maskedAadhar,
            onCopy: () => _c.copyToClipboard(student.aadhar!, 'Aadhar'),
          ),
      ],
    );
  }

  Widget _personalCard() {
    return _DetailCard(
      title: 'Personal',
      children: [
        _DetailRow(
          icon: Icons.cake_rounded,
          label: 'Date of birth',
          value: student.hasDob
              ? '${student.formattedDob}${student.ageText.isNotEmpty ? ' (${student.ageText})' : ''}'
              : 'Not registered',
          muted: !student.hasDob,
          iconColor: AppColors.secondaryDark,
        ),
        if (_has(student.bloodGroup))
          _DetailRow(
            icon: Icons.bloodtype_rounded,
            label: 'Blood group',
            value: student.bloodGroup!,
            iconColor: AppColors.cancelledRed,
          ),
        _DetailRow(
          icon: Icons.home_rounded,
          label: 'Address',
          value: student.displayAddress,
          muted: !student.hasAddress,
          stacked: true,
          onCopy: student.hasAddress
              ? () => _c.copyToClipboard(student.displayAddress, 'Address')
              : null,
        ),
      ],
    );
  }

  Widget _familyCard() {
    return _DetailCard(
      title: 'Family',
      children: [
        if (_has(student.fatherName))
          _DetailRow(
            icon: Icons.man_rounded,
            label: 'Father',
            value: student.fatherName!,
            onCopy: () => _c.copyToClipboard(student.fatherName!, 'Father name'),
          ),
        if (_has(student.motherName))
          _DetailRow(
            icon: Icons.woman_rounded,
            label: 'Mother',
            value: student.motherName!,
            onCopy: () => _c.copyToClipboard(student.motherName!, 'Mother name'),
          ),
      ],
    );
  }

  // --------------------------------------------------------------- contacts

  /// Father / mother numbers. When both are the same number it is one card
  /// for both parents instead of two identical ones.
  List<Widget> _familyContacts() {
    final cards = <Widget>[];
    final hasFather = _has(student.fatherPhone);
    final hasMother = _has(student.motherPhone);
    String parentLabel(String role, String? name) =>
        _has(name) ? '$role · $name' : role;

    if (hasFather &&
        hasMother &&
        _digitsOf(student.fatherPhone) == _digitsOf(student.motherPhone)) {
      final names = [student.fatherName, student.motherName].where(_has).join(' & ');
      cards.add(_phoneCard(
        phone: student.fatherPhone!,
        label: names.isEmpty ? 'Father & Mother' : 'Father & Mother · $names',
        icon: const Icon(Icons.family_restroom_rounded, size: 22),
        color: AppColors.secondaryDark,
      ));
    } else {
      if (hasFather) {
        cards.add(_phoneCard(
          phone: student.fatherPhone!,
          label: parentLabel('Father', student.fatherName),
          icon: const Icon(Icons.man_rounded, size: 22),
          color: AppColors.secondaryDark,
        ));
      }
      if (hasMother) {
        cards.add(_phoneCard(
          phone: student.motherPhone!,
          label: parentLabel('Mother', student.motherName),
          icon: const Icon(Icons.woman_rounded, size: 22),
          color: const Color(0xFFDB2777),
        ));
      }
    }
    return cards;
  }

  Widget _phoneCard({
    required String phone,
    required String label,
    required Widget icon,
    required Color color,
  }) {
    return _ContactCard(
      leading: _TintedIcon(icon: icon, color: color),
      title: phone,
      subtitle: label,
      actions: [
        _CardAction(
          icon: const Icon(Icons.content_copy_rounded, size: 19),
          label: 'Copy',
          color: AppColors.textSecondary,
          onTap: () => _c.copyToClipboard(phone, label),
        ),
        _CardAction(
          icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 19),
          label: 'WhatsApp',
          color: AppColors.successGreen,
          onTap: () => _c.openWhatsApp(phone),
        ),
        _CardAction(
          icon: const Icon(Icons.message_rounded, size: 19),
          label: 'Message',
          color: _googleBlue,
          onTap: () => _c.sendSms(phone),
        ),
        _CardAction(
          icon: const Icon(Icons.call_rounded, size: 19),
          label: 'Call',
          color: AppColors.primary,
          onTap: () => _c.makeCall(phone),
        ),
      ],
    );
  }
}

// =============================================================== components

/// A titled card of [_DetailRow]s separated by hairlines.
class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.cardPadding,
        AppDimens.gapMd,
        AppDimens.cardPadding,
        AppDimens.gapSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.gapXs),
            child: Text(title.toUpperCase(), style: AppTextStyles.overline),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.borderLight),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final VoidCallback? onCopy;
  final bool muted;

  /// Long values (address): label on top, value below, full width.
  final bool stacked;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.onCopy,
    this.muted = false,
    this.stacked = false,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = AppTextStyles.bodyMd.copyWith(
      fontWeight: FontWeight.w600,
      color: muted ? AppColors.textMuted : AppColors.textPrimary,
      fontStyle: muted ? FontStyle.italic : FontStyle.normal,
    );
    final copy = onCopy == null
        ? null
        : InkResponse(
            onTap: onCopy,
            radius: 18,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.content_copy_rounded, size: 16, color: AppColors.textMuted),
            ),
          );

    final leading = IconBadge(icon: icon, color: iconColor, size: 34);

    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodySm),
                  const SizedBox(height: 2),
                  Text(value ?? '', style: valueStyle.copyWith(height: 1.35)),
                ],
              ),
            ),
            ?copy,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppDimens.gapMd),
          Text(label, style: AppTextStyles.bodySm),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ??
                  Text(
                    value ?? '',
                    style: valueStyle,
                    textAlign: TextAlign.right,
                  ),
            ),
          ),
          ?copy,
        ],
      ),
    );
  }
}

/// Rounded tinted square used as the leading visual on contact cards.
class _TintedIcon extends StatelessWidget {
  final Widget icon;
  final Color color;
  const _TintedIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(44 * 0.32),
      ),
      alignment: Alignment.center,
      child: IconTheme(
        data: IconThemeData(color: color),
        child: DefaultTextStyle(style: TextStyle(color: color), child: icon),
      ),
    );
  }
}

class _CardAction {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// A number / email with a row of labelled actions underneath.
class _ContactCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final List<_CardAction> actions;

  const _ContactCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyles.subtitle.copyWith(fontSize: 14.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.cardPadding,
          AppDimens.gapMd,
          AppDimens.cardPadding,
          AppDimens.gapXs,
        ),
        child: Column(
          children: [
            Row(
              children: [
                leading,
                const SizedBox(width: AppDimens.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      const SizedBox(height: 1),
                      Text(subtitle, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.gapSm),
            const Divider(height: 1, color: AppColors.borderLight),
            Row(
              children: [
                for (final a in actions)
                  Expanded(
                    child: InkWell(
                      onTap: a.onTap,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconTheme(
                              data: IconThemeData(color: a.color),
                              child: a.icon,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              a.label,
                              style: AppTextStyles.caption.copyWith(
                                color: a.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Round tinted action in the quick-action strip. [tinted] false leaves the
/// icon on a plain white disc (the Gmail logo keeps its own colours).
class _QuickAction extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool tinted;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.tinted = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tinted ? color.withValues(alpha: 0.12) : Colors.white,
                  shape: BoxShape.circle,
                  border: tinted ? null : Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: IconTheme(
                  data: IconThemeData(color: color),
                  child: icon,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================== header

/// Navy header matching the phonebook list header: gradient with arcs, round
/// translucent buttons, amber overline, white title and frosted pills. It
/// collapses to a slim bar with the student's name.
class _StudentDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PhonebookStudent student;
  final double topPadding;
  final double contentWidth;
  final VoidCallback onBack;
  final VoidCallback onCopyCode;

  _StudentDetailHeaderDelegate({
    required this.student,
    required this.topPadding,
    required this.contentWidth,
    required this.onBack,
    required this.onCopyCode,
  });

  @override
  double get minExtent => topPadding + 60.0;

  static const _nameStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
    height: 1.15,
  );

  /// Height of the name block (1 or 2 lines), so the header is exactly as tall
  /// as its content instead of leaving a gap for a second line.
  double get _nameHeight {
    final painter = TextPainter(
      text: TextSpan(text: student.name, style: _nameStyle),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth);
    return painter.height;
  }

  // top bar (52) + gap (6) + name + gap (12) + pills (26) + bottom (18)
  @override
  double get maxExtent => topPadding + 52 + 6 + _nameHeight + 12 + 26 + 18;

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, {VoidCallback? onTap}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return onTap == null
        ? pill
        : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: pill);
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    final collapsedTitleOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final cornerRadius = Radius.circular((28.0 * (1.0 - progress)).clamp(0.0, 28.0));
    final isAlumni = student.isAlumni;
    final hasRoom = student.room != null && student.room!.isNotEmpty;
    final hasCode = student.bankCode != null && student.bankCode!.isNotEmpty;

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
                  color: const Color(0xFF03192E).withValues(alpha: 0.22 * progress),
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
            RepaintBoundary(child: CustomPaint(painter: _DetailOrbPainter())),

            // Pinned bar: back, collapsed name, share
            Positioned(
              top: topPadding + 6,
              left: 16,
              right: 16,
              height: 46,
              child: Row(
                children: [
                  _roundButton(Icons.arrow_back_rounded, 'Back', onBack),
                  const SizedBox(width: 12),
                  // Beside the back button: "STUDENT PROFILE" while expanded,
                  // the student's name once collapsed.
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Opacity(
                          opacity: expandedOpacity,
                          child: const Text(
                            'STUDENT PROFILE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: collapsedTitleOpacity,
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Expanded content: avatar, overline, name, pills
            if (expandedOpacity > 0.05)
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        student.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _nameStyle,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (isAlumni) _pill(Icons.school_rounded, 'Alumni / Left'),
                          if (!isAlumni && hasRoom)
                            _pill(Icons.meeting_room_rounded, 'Room ${student.room}'),
                          if (student.groupName != null && student.groupName!.isNotEmpty)
                            _pill(Icons.apartment_rounded, student.groupName!),
                          if (hasCode)
                            _pill(
                              Icons.content_copy_rounded,
                              'Code: ${student.bankCode}',
                              onTap: onCopyCode,
                            ),
                        ],
                      ),
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
  bool shouldRebuild(covariant _StudentDetailHeaderDelegate oldDelegate) =>
      oldDelegate.student != student ||
      oldDelegate.topPadding != topPadding ||
      oldDelegate.contentWidth != contentWidth;
}

class _DetailOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final c = Offset(size.width * 0.88, size.height * 0.08);
    canvas.drawCircle(c, size.width * 0.38, strokePaint);
    canvas.drawCircle(c, size.width * 0.62, strokePaint);
    canvas.drawCircle(c, size.width * 0.86, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A number / email on one line with a copy hint; tap copies it.
class _CopyLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String caption;
  final VoidCallback onTap;

  const _CopyLine({
    required this.icon,
    required this.color,
    required this.text,
    required this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 34),
            const SizedBox(width: AppDimens.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 14.5),
                  ),
                  Text(caption, style: AppTextStyles.bodySm),
                ],
              ),
            ),
            const Icon(Icons.content_copy_rounded, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Gmail-style envelope: red "M" flap with blue / green side edges. (Gmail's
/// logo is not in Material Icons or Font Awesome, so it is drawn here.)
class GmailIcon extends StatelessWidget {
  final double size;
  const GmailIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _GmailPainter()));
  }
}

class _GmailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height * 0.78;
    final top = (size.height - h) / 2;
    final edge = w * 0.16;

    Paint fill(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    // Side edges.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, top, edge, h),
        topLeft: Radius.circular(w * 0.08),
        bottomLeft: Radius.circular(w * 0.08),
      ),
      fill(const Color(0xFF4285F4)),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w - edge, top, edge, h),
        topRight: Radius.circular(w * 0.08),
        bottomRight: Radius.circular(w * 0.08),
      ),
      fill(const Color(0xFF34A853)),
    );

    // Red M flap.
    final m = Path()
      ..moveTo(0, top + h * 0.12)
      ..lineTo(edge * 0.4, top)
      ..lineTo(w / 2, top + h * 0.5)
      ..lineTo(w - edge * 0.4, top)
      ..lineTo(w, top + h * 0.12)
      ..lineTo(w, top + h * 0.34)
      ..lineTo(w / 2, top + h * 0.74)
      ..lineTo(0, top + h * 0.34)
      ..close();
    canvas.drawPath(m, fill(const Color(0xFFEA4335)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "Student contact" card whose number / email lines fold away with a chevron
/// in the header. The action buttons stay visible either way.
class _CollapsibleContactCard extends StatefulWidget {
  final List<Widget> lines;
  final Widget actions;
  const _CollapsibleContactCard({required this.lines, required this.actions});

  @override
  State<_CollapsibleContactCard> createState() => _CollapsibleContactCardState();
}

class _CollapsibleContactCardState extends State<_CollapsibleContactCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.cardPadding,
        AppDimens.gapSm,
        AppDimens.cardPadding,
        AppDimens.gapMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.gapSm),
              child: Row(
                children: [
                  Expanded(
                    child: Text('STUDENT CONTACT', style: AppTextStyles.overline),
                  ),
                  if (!_expanded)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${widget.lines.length} ${widget.lines.length == 1 ? 'item' : 'items'}',
                        style: AppTextStyles.bodySm,
                      ),
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(children: widget.lines)
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: AppDimens.gapXs),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppDimens.gapSm),
          widget.actions,
        ],
      ),
    );
  }
}
