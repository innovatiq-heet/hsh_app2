import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/students/student_contacts_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/students/student_contacts_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';
import '../services/phonebook_database_service.dart';

/// Who an additional phone number belongs to (Student, Father, or Mother).
enum ContactOwner { student, father, mother }

/// Modal bottom sheet providing a dedicated UI to add or edit a student's or parent's
/// contact number with support for international numbers (India, USA, UK, Canada, etc.),
/// labels, WhatsApp, and SIM status.
class AddContactNumberSheet extends StatefulWidget {
  final PhonebookStudent student;
  final StudentAdditionalPhone? existingContact;
  final ContactOwner initialOwner;
  final VoidCallback? onSaved;

  const AddContactNumberSheet({
    super.key,
    required this.student,
    this.existingContact,
    this.initialOwner = ContactOwner.student,
    this.onSaved,
  });

  /// Presents the Add / Edit Contact Number bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    required PhonebookStudent student,
    StudentAdditionalPhone? existingContact,
    ContactOwner initialOwner = ContactOwner.student,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddContactNumberSheet(
        student: student,
        existingContact: existingContact,
        initialOwner: initialOwner,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddContactNumberSheet> createState() => _AddContactNumberSheetState();
}

class _AddContactNumberSheetState extends State<AddContactNumberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _customLabelController = TextEditingController();

  late final StudentContactsRepository _repo;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isWhatsApp = false;
  bool _isPrimaryWhatsApp = false;
  bool _isPrimary = false;
  bool _isCustomLabel = false;
  ContactOwner _owner = ContactOwner.student;
  String _selectedLabel = 'USA Mobile';

  static const List<({String label, String iconText})> _studentPresetLabels = [
    (label: 'USA Mobile', iconText: '🇺🇸'),
    (label: 'UK Mobile', iconText: '🇬🇧'),
    (label: 'Canada Mobile', iconText: '🇨🇦'),
    (label: 'Personal SIM', iconText: '📱'),
    (label: 'Local SIM', iconText: '🇮🇳'),
    (label: 'Work', iconText: '💼'),
    (label: 'Guardian', iconText: '👤'),
    (label: 'Other', iconText: '✏️'),
  ];

  static const List<({String label, String iconText})> _parentPresetLabels = [
    (label: 'India', iconText: '🇮🇳'),
    (label: 'Abroad', iconText: '🌍'),
    (label: 'USA', iconText: '🇺🇸'),
    (label: 'UK', iconText: '🇬🇧'),
    (label: 'Canada', iconText: '🇨🇦'),
    (label: 'Australia', iconText: '🇦🇺'),
    (label: 'Work', iconText: '💼'),
    (label: 'Other', iconText: '✏️'),
  ];

  List<({String label, String iconText})> get _activePresets =>
      _owner == ContactOwner.student ? _studentPresetLabels : _parentPresetLabels;

  Color get _ownerAccentColor {
    switch (_owner) {
      case ContactOwner.student:
        return AppColors.primary;
      case ContactOwner.father:
        return AppColors.secondaryDark;
      case ContactOwner.mother:
        return const Color(0xFFDB2777);
    }
  }

  String _defaultLabelFor(ContactOwner owner) {
    switch (owner) {
      case ContactOwner.student:
        return 'USA Mobile';
      case ContactOwner.father:
        return widget.student.hasFatherPhone ? 'Abroad' : 'India';
      case ContactOwner.mother:
        return widget.student.hasMotherPhone ? 'Abroad' : 'India';
    }
  }

  String _buildEffectiveLabel() {
    final base = _isCustomLabel
        ? _customLabelController.text.trim()
        : _selectedLabel;
    if (_owner == ContactOwner.student) return base;
    final prefix = _owner == ContactOwner.father ? 'Father' : 'Mother';
    if (base.toLowerCase().startsWith(prefix.toLowerCase())) {
      return base;
    }
    return '$prefix - $base';
  }

  @override
  void initState() {
    super.initState();
    _repo = Get.find<StudentContactsRepository>();
    _isEditing = widget.existingContact != null;
    _owner = widget.initialOwner;
    _selectedLabel = _defaultLabelFor(_owner);

    if (_isEditing) {
      final c = widget.existingContact!;
      _phoneController.text = c.phone;
      _isWhatsApp = c.isWhatsApp;

      final lowerLabel = c.label.trim().toLowerCase();
      String strippedLabel = c.label.trim();
      if (lowerLabel.startsWith('father')) {
        _owner = ContactOwner.father;
        strippedLabel = c.label
            .trim()
            .replaceFirst(RegExp(r'^father\s*[-–·:(]?\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'\)$'), '')
            .trim();
      } else if (lowerLabel.startsWith('mother')) {
        _owner = ContactOwner.mother;
        strippedLabel = c.label
            .trim()
            .replaceFirst(RegExp(r'^mother\s*[-–·:(]?\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'\)$'), '')
            .trim();
      } else {
        _owner = ContactOwner.student;
      }

      if (_owner == ContactOwner.student) {
        _isPrimary = c.isPrimary;
        _isPrimaryWhatsApp = c.isPrimaryWhatsApp ||
            (widget.student.whatsappNumber != null &&
                widget.student.whatsappNumber!.isNotEmpty &&
                widget.student.whatsappNumber == c.phone);
      } else {
        _isPrimary = false;
        _isPrimaryWhatsApp = false;
      }

      final presets = _activePresets;
      final match = presets.where(
        (p) => p.label.toLowerCase() == strippedLabel.toLowerCase(),
      );
      if (match.isNotEmpty) {
        _selectedLabel = match.first.label;
        _isCustomLabel = false;
      } else {
        _selectedLabel = 'Other';
        _isCustomLabel = true;
        _customLabelController.text =
            strippedLabel.isNotEmpty ? strippedLabel : c.label;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _customLabelController.dispose();
    super.dispose();
  }

  String _resolveTargetIdentifier() {
    final s = widget.student;
    // Prefer studentId (e.g. HSH-0072), bankCode, or id
    if (s.studentId.isNotEmpty && s.studentId.toLowerCase() != 'n/a') {
      return s.studentId.trim();
    }
    if (s.bankCode != null && s.bankCode!.trim().isNotEmpty) {
      return s.bankCode!.trim();
    }
    return s.id.trim();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final effectiveLabel = _buildEffectiveLabel();
    final isStudentOwner = _owner == ContactOwner.student;
    final effectivePrimary = isStudentOwner && _isPrimary;
    final effectivePrimaryWa = isStudentOwner && _isPrimaryWhatsApp;
    final effectiveWa = _isWhatsApp || effectivePrimaryWa;

    setState(() => _isSaving = true);

    try {
      final identifier = _resolveTargetIdentifier();

      if (_isEditing) {
        await _repo.updateAdditionalPhone(
          studentIdentifier: identifier,
          contactId: widget.existingContact!.id,
          phone: phone,
          label: effectiveLabel,
          isWhatsApp: effectiveWa,
          isPrimary: effectivePrimary,
          isPrimaryWhatsApp: effectivePrimaryWa,
        );
        // Remove stale cache row if phone or label changed
        if (widget.existingContact!.phone != phone ||
            widget.existingContact!.label != effectiveLabel) {
          await PhonebookDatabaseService.instance.deleteAdditionalPhone(
            studentId: widget.student.studentId,
            phone: widget.existingContact!.phone,
          );
        }
      } else {
        await _repo.addAdditionalPhone(
          studentIdentifier: identifier,
          phone: phone,
          label: effectiveLabel,
          isWhatsApp: effectiveWa,
          isPrimary: effectivePrimary,
          isPrimaryWhatsApp: effectivePrimaryWa,
        );
      }

      // Update local SQLite phonebook cache
      await PhonebookDatabaseService.instance.insertAdditionalPhone(
        studentId: widget.student.studentId,
        studentCode: widget.student.bankCode,
        phone: phone,
        label: effectiveLabel,
        isPrimary: effectivePrimary,
      );

      // If set as primary WhatsApp (student only), update base contacts in local SQLite cache
      if (effectivePrimaryWa) {
        await PhonebookDatabaseService.instance.updateBaseContacts(
          studentId: widget.student.studentId,
          whatsappNumber: phone,
        );
      }

      // If set as primary mobile (student only), update base contacts in local SQLite cache
      if (effectivePrimary) {
        await PhonebookDatabaseService.instance.updateBaseContacts(
          studentId: widget.student.studentId,
          primaryPhone: phone,
        );
      }

      // Trigger controller search refresh
      if (Get.isRegistered<PhonebookController>()) {
        Get.find<PhonebookController>().search();
      }

      widget.onSaved?.call();

      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.success(
          _isEditing ? 'Contact Updated' : 'Contact Added',
          'Phone number $phone ($effectiveLabel) has been saved.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.error(
          'Save Failed',
          e is ApiException ? e.message : e.toString(),
        );
      }
    }
  }

  Future<void> _deleteContact() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contact Number?'),
        content: Text(
          'Are you sure you want to delete ${widget.existingContact!.phone} (${widget.existingContact!.label}) for ${widget.student.name}?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cancelledRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final identifier = _resolveTargetIdentifier();
      await _repo.deleteAdditionalPhone(
        studentIdentifier: identifier,
        contactId: widget.existingContact!.id,
      );

      await PhonebookDatabaseService.instance.deleteAdditionalPhone(
        studentId: widget.student.studentId,
        phone: widget.existingContact!.phone,
      );

      if (Get.isRegistered<PhonebookController>()) {
        Get.find<PhonebookController>().search();
      }

      widget.onSaved?.call();

      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.success('Contact Deleted', 'The contact number has been deleted.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.error(
          'Delete Failed',
          e is ApiException ? e.message : e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, keyboardHeight + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator
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

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit_rounded : Icons.add_call,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing
                              ? 'Edit Contact Number'
                              : 'Add New Contact Number',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Support for international & secondary phone numbers',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Student Banner Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        widget.student.name.isNotEmpty
                            ? widget.student.name[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.student.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (widget.student.room != null &&
                                  widget.student.room!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    'Room ${widget.student.room}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              if (widget.student.bankCode != null &&
                                  widget.student.bankCode!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Code: ${widget.student.bankCode}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
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
              ),
              const SizedBox(height: 18),

              // Contact Owner Selector (Student / Father / Mother)
              const Text(
                'Add Number For',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ownerOptionTile(
                    owner: ContactOwner.student,
                    label: 'Student',
                    icon: Icons.person_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _ownerOptionTile(
                    owner: ContactOwner.father,
                    label: 'Father',
                    icon: Icons.man_rounded,
                    color: AppColors.secondaryDark,
                  ),
                  const SizedBox(width: 8),
                  _ownerOptionTile(
                    owner: ContactOwner.mother,
                    label: 'Mother',
                    icon: Icons.woman_rounded,
                    color: const Color(0xFFDB2777),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Phone Number Input
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofocus: !_isEditing,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  hintText: '+1 415 555 2671 / +91 98250 12345',
                  hintStyle: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  suffixIcon: _phoneController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _phoneController.clear()),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  final digits = text.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 6 || digits.length > 16) {
                    return 'Phone number must have between 6 and 16 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Label / Type Selector
              Text(
                _owner == ContactOwner.student
                    ? 'Label / Country'
                    : '${_owner == ContactOwner.father ? "Father's" : "Mother's"} Number Type (India / Abroad)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _activePresets.map((preset) {
                  final isSelected = _selectedLabel == preset.label;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(preset.iconText,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          preset.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: _ownerAccentColor,
                    backgroundColor: const Color(0xFFF1F5F9),
                    elevation: isSelected ? 1 : 0,
                    side: BorderSide(
                      color: isSelected
                          ? _ownerAccentColor
                          : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedLabel = preset.label;
                          _isCustomLabel = preset.label == 'Other';
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              // Custom Label Input (shown when "Other" is chosen)
              if (_isCustomLabel) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customLabelController,
                  decoration: InputDecoration(
                    labelText: 'Custom Label',
                    hintText: 'e.g. Dubai SIM, Hostel Roommate, Aunt',
                    prefixIcon: const Icon(Icons.label_outline_rounded,
                        color: AppColors.primary, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  validator: (val) {
                    if (_isCustomLabel && (val == null || val.trim().isEmpty)) {
                      return 'Please enter a custom label';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 18),

              // WhatsApp Options Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Active on WhatsApp toggle
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            size: 18,
                            color: AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active on WhatsApp',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 1.5),
                              Text(
                                'Allows 1-tap WhatsApp chat from directory',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isWhatsApp || _isPrimaryWhatsApp,
                          activeThumbColor: AppColors.successGreen,
                          onChanged: (val) {
                            setState(() {
                              _isWhatsApp = val;
                              if (!val) _isPrimaryWhatsApp = false;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_owner == ContactOwner.student) ...[
                      const Divider(height: 18, thickness: 1, color: Color(0xFFE2E8F0)),
                      // Primary WhatsApp for Calls toggle (student only)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Primary for WhatsApp Calls',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 1.5),
                                Text(
                                  'Main WhatsApp number for direct WhatsApp calls',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPrimaryWhatsApp,
                            activeThumbColor: const Color(0xFF16A34A),
                            onChanged: (val) {
                              setState(() {
                                _isPrimaryWhatsApp = val;
                                if (val) _isWhatsApp = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_owner == ContactOwner.student) ...[
                const SizedBox(height: 12),

                // Set as Primary Student Mobile SIM Card (student only)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.sim_card_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set as Primary Student Mobile',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 1.5),
                            Text(
                              'Main SIM phone number for normal calling',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPrimary,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isPrimary = val),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Save Changes' : 'Add Contact Number',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              // Delete button if editing
              if (_isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _deleteContact,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.cancelledRed),
                  label: const Text(
                    'Delete This Number',
                    style: TextStyle(
                      color: AppColors.cancelledRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.cancelledRed.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerOptionTile({
    required ContactOwner owner,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _owner == owner;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_owner == owner) return;
          setState(() {
            _owner = owner;
            _selectedLabel = _defaultLabelFor(owner);
            _isCustomLabel = false;
            if (owner != ContactOwner.student) {
              _isPrimary = false;
              _isPrimaryWhatsApp = false;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
