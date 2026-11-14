import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/students/student_contacts_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/students/student_contacts_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';
import '../services/phone_number_normalizer.dart';
import '../services/phonebook_database_service.dart';
import 'add_contact_number_sheet.dart';

class ManageContactsSheet extends StatefulWidget {
  final PhonebookStudent student;
  final VoidCallback? onContactsUpdated;

  const ManageContactsSheet({
    super.key,
    required this.student,
    this.onContactsUpdated,
  });

  static Future<bool?> show(
    BuildContext context,
    PhonebookStudent student, {
    VoidCallback? onContactsUpdated,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManageContactsSheet(
        student: student,
        onContactsUpdated: onContactsUpdated,
      ),
    );
  }

  @override
  State<ManageContactsSheet> createState() => _ManageContactsSheetState();
}

class _ManageContactsSheetState extends State<ManageContactsSheet> {
  final StudentContactsRepository _repo = Get.find<StudentContactsRepository>();

  bool _isLoading = true;
  String? _error;
  String? _resolvedIdentifier;

  String? _primaryPhone;
  String? _whatsappNumber;
  String? _fatherPhone;
  String? _motherPhone;
  List<StudentAdditionalPhone> _additionalPhones = [];

  @override
  void initState() {
    super.initState();
    _initFallbackData();
    _loadContacts();
  }

  void _initFallbackData() {
    _primaryPhone = widget.student.primaryPhone != 'No Phone'
        ? widget.student.primaryPhone
        : null;
    _whatsappNumber = widget.student.whatsappNumber;
    _fatherPhone = widget.student.fatherPhone;
    _motherPhone = widget.student.motherPhone;
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Resolve student identifier
      String identifier = widget.student.studentId.trim();
      if (identifier.isEmpty || identifier.toLowerCase() == 'n/a') {
        identifier = widget.student.id.trim();
      }

      // If identifier still not numeric, try resolving through PhonebookController
      if (int.tryParse(identifier) == null &&
          Get.isRegistered<PhonebookController>()) {
        final found = await Get.find<PhonebookController>()
            .findScreenTimeStudentId(widget.student);
        if (found != null && found.isNotEmpty) {
          identifier = found;
        }
      }

      if (identifier.isEmpty) {
        identifier = widget.student.id;
      }
      _resolvedIdentifier = identifier;

      // 2. Fetch live contact data from backend
      final data = await _repo.getContacts(_resolvedIdentifier!);
      if (mounted) {
        setState(() {
          if (data.studentId > 0) {
            _resolvedIdentifier = data.studentId.toString();
          }
          _primaryPhone = data.primaryPhone ?? _primaryPhone;
          _whatsappNumber = data.whatsappNumber ?? _whatsappNumber;
          _fatherPhone = data.fatherPhone ?? _fatherPhone;
          _motherPhone = data.motherPhone ?? _motherPhone;
          _additionalPhones = List.from(data.additionalContacts);
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _notifyUpdated() {
    widget.onContactsUpdated?.call();
    if (Get.isRegistered<PhonebookController>()) {
      Get.find<PhonebookController>().search();
    }
  }

  // ===========================================================================
  // EDIT BASE CONTACT DIALOG
  // ===========================================================================
  Future<void> _editBaseContact({
    required String title,
    required String fieldKey,
    required String? currentValue,
  }) async {
    final controller = TextEditingController(text: currentValue ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<String>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        final hasExistingValue = currentValue != null && currentValue.trim().isNotEmpty;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter contact number (international format supported, e.g. +1 415 555 2671 or +91 98765 43210)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+1 415 555 2671',
                        prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        final val = value?.trim() ?? '';
                        if (val.isEmpty) {
                          return 'Phone number cannot be empty';
                        }
                        if (val.replaceAll(RegExp(r'\D'), '').length < 6) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                if (hasExistingValue)
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _deleteBaseContact(
                              title: title,
                              fieldKey: fieldKey,
                              phone: currentValue,
                            );
                          },
                    child: const Text(
                      'Delete Number',
                      style: TextStyle(
                        color: AppColors.cancelledRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final newPhone = controller.text.trim();
                          setDialogState(() => isSaving = true);

                          try {
                            String id = _resolvedIdentifier ?? widget.student.id;
                            if (fieldKey == 'primary_and_whatsapp') {
                              await _repo.updateBaseContactDetails(
                                studentIdentifier: id,
                                primaryPhone: newPhone,
                                whatsappNumber: newPhone,
                              );

                              // Update local SQLite
                              await PhonebookDatabaseService.instance.updateBaseContacts(
                                studentId: widget.student.studentId,
                                primaryPhone: newPhone,
                                whatsappNumber: newPhone,
                              );

                              if (mounted) {
                                setState(() {
                                  _primaryPhone = newPhone;
                                  _whatsappNumber = newPhone;
                                });
                              }
                            } else {
                              await _repo.updateBaseContactDetails(
                                studentIdentifier: id,
                                primaryPhone: fieldKey == 'primary' ? newPhone : null,
                                whatsappNumber: fieldKey == 'whatsapp' ? newPhone : null,
                                fatherPhone: fieldKey == 'father' ? newPhone : null,
                                motherPhone: fieldKey == 'mother' ? newPhone : null,
                              );

                              // Update local SQLite
                              await PhonebookDatabaseService.instance.updateBaseContacts(
                                studentId: widget.student.studentId,
                                primaryPhone: fieldKey == 'primary' ? newPhone : null,
                                whatsappNumber: fieldKey == 'whatsapp' ? newPhone : null,
                                fatherPhone: fieldKey == 'father' ? newPhone : null,
                                motherPhone: fieldKey == 'mother' ? newPhone : null,
                              );

                              if (mounted) {
                                setState(() {
                                  if (fieldKey == 'primary') _primaryPhone = newPhone;
                                  if (fieldKey == 'whatsapp') _whatsappNumber = newPhone;
                                  if (fieldKey == 'father') _fatherPhone = newPhone;
                                  if (fieldKey == 'mother') _motherPhone = newPhone;
                                });
                              }
                            }
                            _notifyUpdated();
                            if (ctx.mounted) Navigator.pop(ctx, newPhone);
                            AppSnackbar.success('Updated', '$title updated successfully.');
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            AppSnackbar.error(
                              'Update Failed',
                              e is ApiException ? e.message : e.toString(),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // DELETE BASE CONTACT
  // ===========================================================================
  Future<void> _deleteBaseContact({
    required String title,
    required String fieldKey,
    required String phone,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $title?'),
        content: Text(
          'Are you sure you want to remove $phone as $title for ${widget.student.name}?',
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

    try {
      String id = _resolvedIdentifier ?? widget.student.id;
      if (fieldKey == 'primary_and_whatsapp') {
        await _repo.deleteBaseContact(
          studentIdentifier: id,
          fieldKey: 'primary',
        );
        await _repo.deleteBaseContact(
          studentIdentifier: id,
          fieldKey: 'whatsapp',
        );

        // Update local SQLite
        await PhonebookDatabaseService.instance.updateBaseContacts(
          studentId: widget.student.studentId,
          clearPrimary: true,
          clearWhatsApp: true,
        );

        if (mounted) {
          setState(() {
            _primaryPhone = null;
            _whatsappNumber = null;
          });
        }
      } else {
        await _repo.deleteBaseContact(
          studentIdentifier: id,
          fieldKey: fieldKey,
        );

        // Update local SQLite
        await PhonebookDatabaseService.instance.updateBaseContacts(
          studentId: widget.student.studentId,
          clearPrimary: fieldKey == 'primary',
          clearWhatsApp: fieldKey == 'whatsapp',
          clearFather: fieldKey == 'father',
          clearMother: fieldKey == 'mother',
        );

        if (mounted) {
          setState(() {
            if (fieldKey == 'primary') _primaryPhone = null;
            if (fieldKey == 'whatsapp') _whatsappNumber = null;
            if (fieldKey == 'father') _fatherPhone = null;
            if (fieldKey == 'mother') _motherPhone = null;
          });
        }
      }
      _notifyUpdated();
      AppSnackbar.success('Deleted', '$title removed successfully.');
    } catch (e) {
      AppSnackbar.error(
        'Delete Failed',
        e is ApiException ? e.message : e.toString(),
      );
    }
  }

  // ===========================================================================
  // SET ADDITIONAL PHONE AS PRIMARY WHATSAPP
  // ===========================================================================
  Future<void> _setAdditionalPhoneAsPrimaryWhatsApp(StudentAdditionalPhone phone) async {
    try {
      String id = _resolvedIdentifier ?? widget.student.id;
      await _repo.updateAdditionalPhone(
        studentIdentifier: id,
        contactId: phone.id,
        phone: phone.phone,
        label: phone.label,
        isWhatsApp: true,
        isPrimary: phone.isPrimary,
        isPrimaryWhatsApp: true,
      );

      // Update local SQLite cache
      await PhonebookDatabaseService.instance.updateBaseContacts(
        studentId: widget.student.studentId,
        whatsappNumber: phone.phone,
      );

      await _loadContacts();
      _notifyUpdated();
      AppSnackbar.success(
        'WhatsApp Number Updated',
        '${phone.phone} is now the primary WhatsApp number.',
      );
    } catch (e) {
      AppSnackbar.error(
        'Update Failed',
        e is ApiException ? e.message : e.toString(),
      );
    }
  }

  // ===========================================================================
  // SET STUDENT MOBILE AS PRIMARY WHATSAPP
  // ===========================================================================
  Future<void> _setPrimaryMobileAsWhatsApp() async {
    if (_primaryPhone == null || _primaryPhone!.isEmpty) return;
    try {
      String id = _resolvedIdentifier ?? widget.student.id;
      await _repo.updateBaseContactDetails(
        studentIdentifier: id,
        whatsappNumber: _primaryPhone,
      );

      await PhonebookDatabaseService.instance.updateBaseContacts(
        studentId: widget.student.studentId,
        whatsappNumber: _primaryPhone,
      );

      if (mounted) {
        setState(() {
          _whatsappNumber = _primaryPhone;
        });
      }
      _notifyUpdated();
      AppSnackbar.success(
        'WhatsApp Number Updated',
        '$_primaryPhone is now the primary WhatsApp number.',
      );
    } catch (e) {
      AppSnackbar.error(
        'Update Failed',
        e is ApiException ? e.message : e.toString(),
      );
    }
  }

  // ===========================================================================
  // ADD OR EDIT ADDITIONAL PHONE DIALOG
  // ===========================================================================
  Future<void> _showAddOrEditAdditionalPhoneDialog({
    StudentAdditionalPhone? existing,
  }) async {
    final updated = await AddContactNumberSheet.show(
      context,
      student: widget.student,
      existingContact: existing,
      onSaved: () async {
        await _loadContacts();
        _notifyUpdated();
      },
    );
    if (updated == true) {
      await _loadContacts();
      _notifyUpdated();
    }
  }

  // ===========================================================================
  // DELETE ADDITIONAL PHONE
  // ===========================================================================
  Future<void> _deleteAdditionalPhone(StudentAdditionalPhone phone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contact Number?'),
        content: Text(
          'Are you sure you want to remove ${phone.label} (${phone.phone}) for ${widget.student.name}?',
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

    try {
      String id = _resolvedIdentifier ?? widget.student.id;
      await _repo.deleteAdditionalPhone(
        studentIdentifier: id,
        contactId: phone.id,
      );

      // Remove from SQLite
      await PhonebookDatabaseService.instance.deleteAdditionalPhone(
        studentId: widget.student.studentId,
        phone: phone.phone,
      );

      if (mounted) {
        setState(() {
          _additionalPhones.removeWhere((p) => p.id == phone.id);
        });
      }
      _notifyUpdated();
      AppSnackbar.success('Deleted', 'Contact number removed.');
    } catch (e) {
      AppSnackbar.error(
        'Delete Failed',
        e is ApiException ? e.message : e.toString(),
      );
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.contact_phone_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage Student Contacts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.student.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add international phone numbers (e.g. USA, Canada), set primary WhatsApp, or clear old numbers.',
                    style: TextStyle(
                        fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(_error!,
                      style: const TextStyle(color: Color(0xFFEF4444))),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _loadContacts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Base Contacts
                    _buildSectionHeader('PRIMARY & FAMILY NUMBERS'),
                    if (_primaryPhone != null &&
                        _primaryPhone!.trim().isNotEmpty &&
                        _whatsappNumber != null &&
                        _whatsappNumber!.trim().isNotEmpty &&
                        PhoneNumberNormalizer.isSame(_primaryPhone, _whatsappNumber))
                      _buildBaseContactTile(
                        label: 'Mobile & WhatsApp',
                        value: _primaryPhone,
                        icon: Icons.smartphone_rounded,
                        color: AppColors.primary,
                        fieldKey: 'primary_and_whatsapp',
                        badge: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(FontAwesomeIcons.whatsapp,
                                  size: 9.5, color: Color(0xFF16A34A)),
                              SizedBox(width: 3),
                              Text(
                                'Primary WA',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onEdit: () => _editBaseContact(
                          title: 'Edit Mobile & WhatsApp Number',
                          fieldKey: 'primary_and_whatsapp',
                          currentValue: _primaryPhone,
                        ),
                        onDelete: () => _deleteBaseContact(
                          title: 'Mobile & WhatsApp Number',
                          fieldKey: 'primary_and_whatsapp',
                          phone: _primaryPhone!,
                        ),
                      )
                    else ...[
                      _buildBaseContactTile(
                        label: 'Student Mobile',
                        value: _primaryPhone,
                        icon: Icons.smartphone_rounded,
                        color: AppColors.primary,
                        fieldKey: 'primary',
                        badge: (_primaryPhone != null &&
                                _primaryPhone!.isNotEmpty &&
                                (_whatsappNumber == null ||
                                    _whatsappNumber!.isEmpty ||
                                    !PhoneNumberNormalizer.isSame(
                                        _whatsappNumber, _primaryPhone)))
                            ? InkWell(
                                onTap: _setPrimaryMobileAsWhatsApp,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FaIcon(FontAwesomeIcons.whatsapp,
                                          size: 9.5, color: Color(0xFF16A34A)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Use as WA',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                        onEdit: () => _editBaseContact(
                          title: 'Edit Student Mobile',
                          fieldKey: 'primary',
                          currentValue: _primaryPhone,
                        ),
                        onDelete: _primaryPhone != null && _primaryPhone!.isNotEmpty
                            ? () => _deleteBaseContact(
                                  title: 'Student Mobile',
                                  fieldKey: 'primary',
                                  phone: _primaryPhone!,
                                )
                            : null,
                      ),
                      if (!_additionalPhones.any((p) =>
                          PhoneNumberNormalizer.isSame(p.phone, _whatsappNumber)))
                        _buildBaseContactTile(
                          label: 'WhatsApp Number',
                          value: _whatsappNumber,
                          icon: Icons.chat_rounded,
                          color: AppColors.successGreen,
                          fieldKey: 'whatsapp',
                          badge: (_whatsappNumber != null &&
                                  _whatsappNumber!.isNotEmpty)
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFF86EFAC)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FaIcon(FontAwesomeIcons.whatsapp,
                                          size: 9.5, color: Color(0xFF16A34A)),
                                      SizedBox(width: 3),
                                      Text(
                                        'Primary WA',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          onEdit: () => _editBaseContact(
                            title: 'Edit WhatsApp Number',
                            fieldKey: 'whatsapp',
                            currentValue: _whatsappNumber,
                          ),
                          onDelete: _whatsappNumber != null &&
                                  _whatsappNumber!.isNotEmpty
                              ? () => _deleteBaseContact(
                                    title: 'WhatsApp Number',
                                    fieldKey: 'whatsapp',
                                    phone: _whatsappNumber!,
                                  )
                              : null,
                        ),
                    ],
                    _buildBaseContactTile(
                      label: "Father's Phone",
                      value: _fatherPhone,
                      icon: Icons.man_rounded,
                      color: AppColors.secondaryDark,
                      fieldKey: 'father',
                      onEdit: () => _editBaseContact(
                        title: "Edit Father's Phone",
                        fieldKey: 'father',
                        currentValue: _fatherPhone,
                      ),
                      onDelete: _fatherPhone != null &&
                              _fatherPhone!.isNotEmpty
                          ? () => _deleteBaseContact(
                                title: "Father's Phone",
                                fieldKey: 'father',
                                phone: _fatherPhone!,
                              )
                          : null,
                    ),
                    _buildBaseContactTile(
                      label: "Mother's Phone",
                      value: _motherPhone,
                      icon: Icons.woman_rounded,
                      color: const Color(0xFFDB2777),
                      fieldKey: 'mother',
                      onEdit: () => _editBaseContact(
                        title: "Edit Mother's Phone",
                        fieldKey: 'mother',
                        currentValue: _motherPhone,
                      ),
                      onDelete: _motherPhone != null &&
                              _motherPhone!.isNotEmpty
                          ? () => _deleteBaseContact(
                                title: "Mother's Phone",
                                fieldKey: 'mother',
                                phone: _motherPhone!,
                              )
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Additional & International Numbers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('ADDITIONAL & INTERNATIONAL NUMBERS'),
                        InkWell(
                          onTap: () =>
                              _showAddOrEditAdditionalPhoneDialog(),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle_outline_rounded,
                                    size: 15, color: AppColors.primary),
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
                    ),
                    const SizedBox(height: 6),

                    if (_additionalPhones.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              size: 32,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No additional numbers added yet.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add USA, UK, Canada or secondary SIM cards so they appear directly in the Hostel Phonebook.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showAddOrEditAdditionalPhoneDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Phone Number'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._additionalPhones
                          .where((phone) =>
                              _primaryPhone == null ||
                              _primaryPhone!.isEmpty ||
                              !PhoneNumberNormalizer.isSame(
                                  phone.phone, _primaryPhone))
                          .map(
                            (phone) => _buildAdditionalPhoneTile(phone),
                          ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildBaseContactTile({
    required String label,
    required String? value,
    required IconData icon,
    required Color color,
    required String fieldKey,
    required VoidCallback onEdit,
    VoidCallback? onDelete,
    Widget? badge,
  }) {
    final hasVal = value != null && value.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ?badge,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasVal ? value : 'Not Set',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: hasVal ? AppColors.textPrimary : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              if (hasVal && onDelete != null) ...[
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.cancelledRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.cancelledRed,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalPhoneTile(StudentAdditionalPhone phone) {
    final isPrimaryWA = phone.isPrimaryWhatsApp ||
        (_whatsappNumber != null &&
            _whatsappNumber!.isNotEmpty &&
            PhoneNumberNormalizer.isSame(_whatsappNumber, phone.phone));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimaryWA ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (phone.isWhatsApp || isPrimaryWA)
                  ? AppColors.successGreen.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              (phone.isWhatsApp || isPrimaryWA)
                  ? Icons.chat_rounded
                  : Icons.public_rounded,
              color: (phone.isWhatsApp || isPrimaryWA)
                  ? AppColors.successGreen
                  : AppColors.primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        phone.label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    if (isPrimaryWA)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(FontAwesomeIcons.whatsapp,
                                size: 10, color: Color(0xFF16A34A)),
                            SizedBox(width: 3),
                            Text(
                              'Primary WA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      if (phone.isWhatsApp)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: () => _setAdditionalPhoneAsPrimaryWhatsApp(phone),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(FontAwesomeIcons.whatsapp,
                                  size: 10, color: Color(0xFF475569)),
                              SizedBox(width: 3),
                              Text(
                                'Set as Primary WA',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  phone.phone,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      _showAddOrEditAdditionalPhoneDialog(existing: phone),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _deleteAdditionalPhone(phone),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cancelledRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.cancelledRed,
                    ),
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
