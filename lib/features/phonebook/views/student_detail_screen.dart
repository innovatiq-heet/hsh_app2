import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_badge.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/student_contact_card.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';
import '../services/phone_number_normalizer.dart';
import '../services/phonebook_database_service.dart';
import '../widgets/add_contact_number_sheet.dart';
import '../widgets/manage_contacts_sheet.dart';
import '../widgets/student_tag_sheet.dart';

/// Full-screen profile of one phonebook student: navy header, quick actions,
/// hostel / personal / family details and every contact number with its own
/// copy, WhatsApp, message and call actions.
class StudentDetailScreen extends StatefulWidget {
  final PhonebookStudent student;
  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late PhonebookStudent _student;

  PhonebookStudent get student => _student;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
  }

  @override
  void didUpdateWidget(covariant StudentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student != widget.student) {
      _student = widget.student;
    }
  }

  Future<void> _openManageContacts() async {
    final res = await ManageContactsSheet.show(
      context,
      _student,
      onContactsUpdated: _refreshStudent,
    );
    if (res == true) {
      await _refreshStudent();
    }
  }

  Future<void> _openAddContactNumber({
    ContactOwner initialOwner = ContactOwner.student,
  }) async {
    final res = await AddContactNumberSheet.show(
      context,
      student: _student,
      initialOwner: initialOwner,
      onSaved: _refreshStudent,
    );
    if (res == true) {
      await _refreshStudent();
    }
  }

  Future<void> _refreshStudent() async {
    try {
      final query = _student.studentId.isNotEmpty ? _student.studentId : _student.name;
      final results = await PhonebookDatabaseService.instance.searchStudents(
        query: query,
        limit: 10,
      );
      if (results.isNotEmpty) {
        final match = results.firstWhere(
          (s) => s.studentId == _student.studentId || s.id == _student.id,
          orElse: () => results.first,
        );
        if (mounted) {
          setState(() {
            _student = match;
          });
        }
      }
    } catch (_) {}
  }

  static const Color _googleBlue = Color(0xFF1A73E8);

  PhonebookController get _c => Get.find<PhonebookController>();

  bool get _hasPhone => student.primaryPhone != 'No Phone';

  static String _digitsOf(String? raw) =>
      PhoneNumberNormalizer.normalize(raw) ??
      (raw ?? '').replaceAll(RegExp(r'\D'), '');

  /// Active expanded sections. All sections default to expanded so details
  /// are immediately visible on open, with full interactive expand/collapse
  /// per card and a master "Collapse all / Expand all" toggle.
  final Set<String> _expandedSections = {
    'contacts',
    'tags',
    'hostel',
    'personal',
    'family_contacts',
  };

  /// Tracks which parent cards ('father', 'mother') have their full details expanded.
  final Set<String> _expandedParents = {};

  List<String> get _availableSections => const [
    'contacts',
    'tags',
    'hostel',
    'personal',
    'family_contacts',
  ];

  bool get _allExpanded => _availableSections.every(_expandedSections.contains);

  void _toggleAll() {
    setState(() {
      if (_allExpanded) {
        _expandedSections.clear();
      } else {
        _expandedSections.addAll(_availableSections);
      }
    });
  }

  void _toggleSection(String section) {
    setState(() {
      if (_expandedSections.contains(section)) {
        _expandedSections.remove(section);
      } else {
        _expandedSections.add(section);
      }
    });
  }

  void _toggleParent(String parentKey) {
    setState(() {
      if (_expandedParents.contains(parentKey)) {
        _expandedParents.remove(parentKey);
      } else {
        _expandedParents.add(parentKey);
      }
    });
  }

  Widget _expandCollapseBar() {
    final allExpanded = _allExpanded;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'STUDENT PROFILE',
                style: AppTextStyles.overline.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _toggleAll,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allExpanded
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    allExpanded ? 'Collapse all' : 'Expand all',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// True when the dedicated WhatsApp number equals one of the student's own
  /// mobile numbers (parents' numbers don't count), so it is not listed twice.
  bool get _whatsappSameAsMobile {
    if (!_has(student.whatsappNumber)) return false;
    final wa = student.whatsappNumber!;
    if (student.primaryPhone != 'No Phone' &&
        PhoneNumberNormalizer.isSame(student.primaryPhone, wa)) {
      return true;
    }
    return student.phones.any((p) {
      final label = p.label.toLowerCase();
      if (label.contains('father') || label.contains('mother')) return false;
      return PhoneNumberNormalizer.isSame(p.phone, wa);
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
                  _expandCollapseBar(),
                  _studentContactCard(),
                  const SizedBox(height: AppDimens.gapMd),
                  _StudentDetailTagsCard(
                    student: student,
                    isExpanded: _expandedSections.contains('tags'),
                    onToggle: () => _toggleSection('tags'),
                  ),
                  const SizedBox(height: AppDimens.gapMd),
                  _hostelCard(),
                  const SizedBox(height: AppDimens.gapMd),
                  _personalCard(),
                  const SizedBox(height: AppDimens.gapMd),
                  _familyContactsSection(),
                  const SizedBox(height: AppDimens.gapLg),
                  AppButton(
                    label: 'Add Contact Number',
                    icon: Icons.add_call,
                    onPressed: _openAddContactNumber,
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  AppButton(
                    label: 'Manage All Contacts',
                    icon: Icons.contact_phone_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: _openManageContacts,
                  ),
                  const SizedBox(height: AppDimens.gapSm),
                  AppButton(
                    label: 'Share complete details',
                    icon: Icons.ios_share_rounded,
                    onPressed: () => _c.shareStudent(student),
                  ),
                  // Alumni have no hostel phone to monitor (Screen Time lists residents only).
                  if (!student.isAlumni) ...[
                    const SizedBox(height: AppDimens.gapSm),
                    _ScreenTimeButton(student: student),
                  ],
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
    final seen = <String>[];

    for (final p in student.phones) {
      final label = p.label.toLowerCase();
      if (label.contains('father') || label.contains('mother')) continue;

      if (seen.any((s) => PhoneNumberNormalizer.isSame(s, p.phone))) continue;
      seen.add(p.phone);

      String effectiveLabel = p.label;
      if (_has(student.whatsappNumber) &&
          PhoneNumberNormalizer.isSame(p.phone, student.whatsappNumber)) {
        effectiveLabel = 'Mobile & WhatsApp';
      }
      out.add((phone: p.phone, label: effectiveLabel));
    }

    if (_has(student.whatsappNumber) && !_whatsappSameAsMobile) {
      if (!seen.any((s) => PhoneNumberNormalizer.isSame(s, student.whatsappNumber))) {
        seen.add(student.whatsappNumber!);
        out.add((phone: student.whatsappNumber!, label: 'WhatsApp'));
      }
    }
    return out;
  }

  /// One card on top: the student's numbers and email (tap to copy) and the
  /// round Call / WhatsApp / Message / Gmail actions.
  Widget _studentContactCard() {
    if (_studentNumbers.isEmpty && !_hasPhone && !_has(student.email)) {
      return AppCard(
        padding: const EdgeInsets.all(AppDimens.cardPadding),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone_disabled_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Contact Number',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add a mobile or USA contact number',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openManageContacts,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final count = _studentNumbers.length;
    final contactSummary = count > 0
        ? '$count ${count == 1 ? 'number' : 'numbers'}${_has(student.email) ? ' · Email' : ''}'
        : (_has(student.email) ? 'Email only' : null);

    return _CollapsibleContactCard(
      isExpanded: _expandedSections.contains('contacts'),
      onToggle: () => _toggleSection('contacts'),
      summary: contactSummary,
      onManage: _openManageContacts,
      onAdd: _openAddContactNumber,
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
              onTap: () => _c.makeCall(student.primaryPhone, student: student),
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
    final roomSummary = _has(student.room)
        ? 'Room ${student.room}${floor != null ? ' · Floor $floor' : ''}'
        : (isAlumni ? 'Alumni' : 'Not allotted');

    return _DetailCard(
      title: 'Hostel',
      isExpanded: _expandedSections.contains('hostel'),
      onToggle: () => _toggleSection('hostel'),
      summary: roomSummary,
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
    final personalSummary = student.hasDob
        ? '${student.formattedDob}${_has(student.bloodGroup) ? ' · ${student.bloodGroup}' : ''}'
        : (_has(student.bloodGroup) ? 'Blood: ${student.bloodGroup}' : null);

    return _DetailCard(
      title: 'Personal',
      isExpanded: _expandedSections.contains('personal'),
      onToggle: () => _toggleSection('personal'),
      summary: personalSummary,
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
        if (student.hasHometown)
          _DetailRow(
            icon: Icons.location_city_rounded,
            label: 'Hometown / Region',
            value: student.hometown,
            iconColor: AppColors.pendingBlue,
            onCopy: () => _c.copyToClipboard(student.hometown, 'Hometown'),
          ),
      ],
    );
  }

  Widget _familyContactsSection() {
    final contacts = _familyContacts();
    final isExpanded = _expandedSections.contains('family_contacts');
    final summary = contacts.isEmpty
        ? 'None'
        : '${contacts.length} ${contacts.length == 1 ? 'contact' : 'contacts'}';

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
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _toggleSection('family_contacts'),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.gapSm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('FAMILY CONTACTS', style: AppTextStyles.overline),
                        ),
                        if (!isExpanded)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              summary,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeInOutCubic,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _openManageContacts,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        'Manage',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      const SizedBox(height: AppDimens.gapXs),
                      if (contacts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No parent contact numbers added yet.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < contacts.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppDimens.gapSm),
                          contacts[i],
                        ],
                      const SizedBox(height: AppDimens.gapSm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openAddContactNumber(
                                initialOwner: ContactOwner.father,
                              ),
                              icon: const Icon(
                                Icons.man_rounded,
                                size: 16,
                                color: AppColors.secondaryDark,
                              ),
                              label: const Text(
                                '+ Father No.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondaryDark,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                side: BorderSide(
                                  color: AppColors.secondaryDark.withValues(alpha: 0.35),
                                ),
                                backgroundColor: AppColors.secondaryDark.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openAddContactNumber(
                                initialOwner: ContactOwner.mother,
                              ),
                              icon: const Icon(
                                Icons.woman_rounded,
                                size: 16,
                                color: Color(0xFFDB2777),
                              ),
                              label: const Text(
                                '+ Mother No.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDB2777),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                side: BorderSide(
                                  color: const Color(0xFFDB2777).withValues(alpha: 0.35),
                                ),
                                backgroundColor: const Color(0xFFDB2777).withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- contacts

  /// Builds up to two parent cards (Father and Mother), each grouping that
  /// parent's primary + extra India/Abroad numbers and expanding on tap to
  /// reveal full parent details (name, profession, DOB, marriage anniversary).
  List<Widget> _familyContacts() {
    final cards = <Widget>[];

    final fatherPhones = <_ParentPhoneEntry>[];
    final seenFatherDigits = <String>{};
    if (_has(student.fatherPhone)) {
      final d = _digitsOf(student.fatherPhone);
      if (d.isNotEmpty) seenFatherDigits.add(d);
      fatherPhones.add(_ParentPhoneEntry(
        phone: student.fatherPhone!,
        label: 'Primary',
      ));
    }
    for (final p in student.phones) {
      final lower = p.label.trim().toLowerCase();
      if (!lower.contains('father')) continue;
      final d = _digitsOf(p.phone);
      if (d.isEmpty || seenFatherDigits.contains(d)) continue;
      seenFatherDigits.add(d);
      fatherPhones.add(_ParentPhoneEntry(
        phone: p.phone,
        label: p.label.trim(),
      ));
    }

    final motherPhones = <_ParentPhoneEntry>[];
    final seenMotherDigits = <String>{};
    if (_has(student.motherPhone)) {
      final d = _digitsOf(student.motherPhone);
      if (d.isNotEmpty) seenMotherDigits.add(d);
      motherPhones.add(_ParentPhoneEntry(
        phone: student.motherPhone!,
        label: 'Primary',
      ));
    }
    for (final p in student.phones) {
      final lower = p.label.trim().toLowerCase();
      if (!lower.contains('mother')) continue;
      final d = _digitsOf(p.phone);
      if (d.isEmpty || seenMotherDigits.contains(d)) continue;
      seenMotherDigits.add(d);
      motherPhones.add(_ParentPhoneEntry(
        phone: p.phone,
        label: p.label.trim(),
      ));
    }

    final hasFatherSection = fatherPhones.isNotEmpty ||
        _has(student.fatherName) ||
        student.hasFatherBusiness ||
        student.hasFatherDob;
    final hasMotherSection = motherPhones.isNotEmpty ||
        _has(student.motherName) ||
        student.hasMotherBusiness ||
        student.hasMotherDob;

    final sharedPrimary = _has(student.fatherPhone) &&
        _has(student.motherPhone) &&
        _digitsOf(student.fatherPhone) == _digitsOf(student.motherPhone);

    if (hasFatherSection) {
      cards.add(_buildParentCard(
        parentKey: 'father',
        role: 'Father',
        owner: ContactOwner.father,
        name: student.fatherName,
        business: student.fatherBusiness,
        dob: student.fatherDob,
        phones: fatherPhones,
        icon: const Icon(Icons.man_rounded, size: 22),
        color: AppColors.secondaryDark,
        isSharedNumber: sharedPrimary,
      ));
    }

    if (hasMotherSection) {
      cards.add(_buildParentCard(
        parentKey: 'mother',
        role: 'Mother',
        owner: ContactOwner.mother,
        name: student.motherName,
        business: student.motherBusiness,
        dob: student.motherDob,
        phones: motherPhones,
        icon: const Icon(Icons.woman_rounded, size: 22),
        color: const Color(0xFFDB2777),
        isSharedNumber: sharedPrimary,
      ));
    }

    return cards;
  }

  List<_CardAction> _actionsForPhone(String phone, String copyLabel) => [
        _CardAction(
          icon: const Icon(Icons.content_copy_rounded, size: 19),
          label: 'Copy',
          color: AppColors.textSecondary,
          onTap: () => _c.copyToClipboard(phone, copyLabel),
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
          onTap: () => _c.makeCall(phone, student: student),
        ),
      ];

  Widget _buildParentCard({
    required String parentKey,
    required String role,
    required ContactOwner owner,
    required String? name,
    required String? business,
    required String? dob,
    required List<_ParentPhoneEntry> phones,
    required Widget icon,
    required Color color,
    bool isSharedNumber = false,
  }) {
    final primaryPhone = phones.isNotEmpty ? phones.first : null;
    final extraPhones = phones.length > 1 ? phones.sublist(1) : const <_ParentPhoneEntry>[];
    final cleanName = _has(name) ? name!.trim() : null;
    final cleanBusiness = _has(business) ? business!.trim() : null;
    final cleanDob = _has(dob) ? dob!.trim() : null;

    final title = primaryPhone != null
        ? primaryPhone.phone
        : (cleanName ?? role);
    final subtitleParts = <String>[
      if (primaryPhone != null)
        (cleanName != null ? '$role · $cleanName' : role)
      else
        '$role · No phone added',
      if (isSharedNumber && primaryPhone != null) 'Shared',
    ];

    final detailRows = <Widget>[
      _DetailRow(
        icon: Icons.badge_outlined,
        label: 'Full name',
        value: cleanName ?? 'Not provided',
        muted: cleanName == null,
        iconColor: color,
        onCopy: cleanName != null
            ? () => _c.copyToClipboard(cleanName, '$role name')
            : null,
      ),
      _DetailRow(
        icon: Icons.work_outline_rounded,
        label: 'Profession',
        value: cleanBusiness ?? 'Not provided',
        muted: cleanBusiness == null,
        iconColor: color,
        onCopy: cleanBusiness != null
            ? () => _c.copyToClipboard(cleanBusiness, "$role's profession")
            : null,
      ),
      _DetailRow(
        icon: Icons.cake_outlined,
        label: 'Date of birth',
        value: cleanDob ?? 'Not provided',
        muted: cleanDob == null,
        iconColor: color,
      ),
      if (student.hasAnniversary)
        _DetailRow(
          icon: Icons.favorite_border_rounded,
          label: "Parents' anniversary",
          value: student.anniversaryFormatted,
          iconColor: const Color(0xFFE11D48),
          onCopy: () => _c.copyToClipboard(
            student.anniversaryFormatted,
            "Parents' anniversary",
          ),
        ),
      if (student.hasHometown)
        _DetailRow(
          icon: Icons.location_city_rounded,
          label: 'Hometown',
          value: student.hometown,
          iconColor: AppColors.pendingBlue,
          onCopy: () => _c.copyToClipboard(student.hometown, 'Hometown'),
        ),
    ];

    return _ParentContactCard(
      leading: _TintedIcon(icon: icon, color: color),
      title: title,
      subtitle: subtitleParts.join(' · '),
      accentColor: color,
      isExpanded: _expandedParents.contains(parentKey),
      onToggleDetails: () => _toggleParent(parentKey),
      detailRows: detailRows,
      primaryActions: primaryPhone != null
          ? _actionsForPhone(
              primaryPhone.phone,
              cleanName != null ? '$role · $cleanName' : role,
            )
          : const [],
      extraPhones: extraPhones,
      buildExtraActions: (entry) => _actionsForPhone(
        entry.phone,
        cleanName != null ? '${entry.label} · $cleanName' : entry.label,
      ),
      onAddNumber: primaryPhone == null
          ? () => _openAddContactNumber(initialOwner: owner)
          : null,
      addNumberLabel: 'Add $role number',
    );
  }
}

/// Card displaying the student's assigned tags and roles (e.g. Karyakarta, Wing Leader)
/// with an action to edit or assign new tags via [StudentTagSheet].
class _StudentDetailTagsCard extends StatefulWidget {
  final PhonebookStudent student;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _StudentDetailTagsCard({
    required this.student,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_StudentDetailTagsCard> createState() => _StudentDetailTagsCardState();
}

class _StudentDetailTagsCardState extends State<_StudentDetailTagsCard> {
  late List<StudentTag> _tags;

  @override
  void initState() {
    super.initState();
    _tags = dedupeTags(widget.student.tags);
    _refreshTags();
  }

  /// The cached phonebook tags can be empty or stale (system tags like
  /// Irregular are calculated by the server), so load the current ones.
  Future<void> _refreshTags() async {
    if (!Get.isRegistered<PhonebookController>()) return;
    final fresh = await Get.find<PhonebookController>().refreshStudentTags(widget.student);
    if (fresh != null && mounted) setState(() => _tags = fresh);
  }

  @override
  void didUpdateWidget(covariant _StudentDetailTagsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student != widget.student) {
      _tags = dedupeTags(widget.student.tags);
    }
  }

  Future<void> _editTags() async {
    final updated = await StudentTagSheet.show(
      context,
      widget.student.copyWith(tags: _tags),
      onTagsUpdated: (newTags) {
        if (mounted) {
          setState(() {
            _tags = dedupeTags(newTags);
          });
        }
      },
    );
    if (updated != null && mounted) {
      setState(() {
        _tags = dedupeTags(updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.cardPadding,
        AppDimens.gapSm,
        AppDimens.cardPadding,
        AppDimens.gapSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.onToggle,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.gapSm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('TAGS & ROLES', style: AppTextStyles.overline),
                        ),
                        if (!widget.isExpanded)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              _tags.isEmpty
                                  ? 'None'
                                  : '${_tags.length} ${_tags.length == 1 ? 'tag' : 'tags'}',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        AnimatedRotation(
                          turns: widget.isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeInOutCubic,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _editTags,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _tags.isEmpty ? 'Add' : 'Edit',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: widget.isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimens.gapXs),
                      if (_tags.isEmpty)
                        InkWell(
                          onTap: _editTags,
                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle_outline_rounded,
                                    size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'No tags assigned yet. Tap to assign roles (e.g. Karyakarta) or tags.',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in _tags)
                              CelebrantLightChip(
                                icon: tag.isSystem
                                    ? Icons.lock_outline_rounded
                                    : Icons.label_rounded,
                                text: tag.name,
                                bgColor: tag.backgroundColor,
                                borderColor: tag.borderColor,
                                textColor: tag.displayColor,
                              ),
                          ],
                        ),
                      const SizedBox(height: AppDimens.gapXs),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// =============================================================== components

/// A titled card of [_DetailRow]s separated by hairlines.
class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? summary;

  const _DetailCard({
    required this.title,
    required this.children,
    required this.isExpanded,
    required this.onToggle,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.cardPadding,
        AppDimens.gapSm,
        AppDimens.cardPadding,
        AppDimens.gapSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.gapSm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title.toUpperCase(), style: AppTextStyles.overline),
                  ),
                  if (!isExpanded && summary != null && summary!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOutCubic,
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
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimens.gapXs),
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.borderLight),
                        children[i],
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
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

class _ParentPhoneEntry {
  final String phone;
  final String label;
  const _ParentPhoneEntry({required this.phone, required this.label});
}

/// Interactive parent card (Father or Mother): shows primary phone + quick
/// actions (and any extra India/Abroad numbers) and expands smoothly on tap
/// to reveal the parent's full details without a separate duplicate Family card.
class _ParentContactCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isExpanded;
  final VoidCallback onToggleDetails;
  final List<Widget> detailRows;
  final List<_CardAction> primaryActions;
  final List<_ParentPhoneEntry> extraPhones;
  final List<_CardAction> Function(_ParentPhoneEntry entry) buildExtraActions;
  final VoidCallback? onAddNumber;
  final String addNumberLabel;

  const _ParentContactCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isExpanded,
    required this.onToggleDetails,
    required this.detailRows,
    required this.primaryActions,
    this.extraPhones = const [],
    required this.buildExtraActions,
    this.onAddNumber,
    this.addNumberLabel = 'Add number',
  });

  Widget _actionStrip(List<_CardAction> actions) {
    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyles.subtitle.copyWith(fontSize: 14.5);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: isExpanded
              ? accentColor.withValues(alpha: 0.45)
              : AppColors.borderLight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.cardPadding,
        AppDimens.gapSm,
        AppDimens.cardPadding,
        AppDimens.gapXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleDetails,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
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
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isExpanded ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isExpanded ? 'Hide' : 'Details',
                          style: AppTextStyles.caption.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Container(
                    margin: const EdgeInsets.only(top: AppDimens.gapSm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < detailRows.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: AppColors.borderLight),
                          detailRows[i],
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (primaryActions.isNotEmpty) ...[
            const SizedBox(height: AppDimens.gapSm),
            const Divider(height: 1, color: AppColors.borderLight),
            _actionStrip(primaryActions),
          ] else if (onAddNumber != null) ...[
            const SizedBox(height: AppDimens.gapSm),
            const Divider(height: 1, color: AppColors.borderLight),
            InkWell(
              onTap: onAddNumber,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_call, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      addNumberLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final extra in extraPhones) ...[
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      extra.label,
                      style: AppTextStyles.caption.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      extra.phone,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            _actionStrip(buildExtraActions(extra)),
          ],
        ],
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

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap, {Color iconColor = Colors.white}) {
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
            child: Icon(icon, color: iconColor, size: 20),
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
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      if (!Get.isRegistered<PhonebookController>()) return const SizedBox.shrink();
                      final c = Get.find<PhonebookController>();
                      return Obx(() {
                        final isFav = c.isFavourite(student.id);
                        return _roundButton(
                          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          isFav ? 'Remove from Favourites' : 'Add to Favourites',
                          () => c.toggleFavourite(student),
                          iconColor: isFav ? const Color(0xFFF59E0B) : Colors.white,
                        );
                      });
                    },
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

/// "View screen time": resolves the student's Screen Time id first so that
/// student's details open directly; when the id can't be told for certain it
/// falls back to Screen Time's directory searched by name.
class _ScreenTimeButton extends StatefulWidget {
  final PhonebookStudent student;
  const _ScreenTimeButton({required this.student});

  @override
  State<_ScreenTimeButton> createState() => _ScreenTimeButtonState();
}

class _ScreenTimeButtonState extends State<_ScreenTimeButton> {
  bool _loading = false;

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    final student = widget.student;
    final id = await Get.find<PhonebookController>().findScreenTimeStudentId(student);
    if (!mounted) return;
    setState(() => _loading = false);
    Get.toNamed(
      Routes.studentScreenTime,
      arguments: {
        'id': ?id,
        'name': student.name,
        'room': student.room ?? '',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'View screen time',
      icon: Icons.timelapse_rounded,
      variant: AppButtonVariant.outline,
      isLoading: _loading,
      onPressed: _open,
    );
  }
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
class _CollapsibleContactCard extends StatelessWidget {
  final List<Widget> lines;
  final Widget actions;
  final VoidCallback? onManage;
  final VoidCallback? onAdd;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String? summary;

  const _CollapsibleContactCard({
    required this.lines,
    required this.actions,
    this.onManage,
    this.onAdd,
    required this.isExpanded,
    required this.onToggle,
    this.summary,
  });

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
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.gapSm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('STUDENT CONTACT', style: AppTextStyles.overline),
                        ),
                        if (!isExpanded && summary != null && summary!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              summary!,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeInOutCubic,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onAdd != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_call, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Add Number',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (onManage != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onManage,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Text(
                          'Manage',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(children: lines)
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: AppDimens.gapXs),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppDimens.gapSm),
          actions,
        ],
      ),
    );
  }
}
