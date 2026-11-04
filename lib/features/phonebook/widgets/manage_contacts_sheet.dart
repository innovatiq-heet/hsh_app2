import 'package:flutter/material.dart';
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
import '../services/phonebook_database_service.dart';

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
  // ADD OR EDIT ADDITIONAL PHONE DIALOG
  // ===========================================================================
  Future<void> _showAddOrEditAdditionalPhoneDialog({
    StudentAdditionalPhone? existing,
  }) async {
    final isEditing = existing != null;
    final phoneController =
        TextEditingController(text: existing?.phone ?? '');
    String selectedLabel = existing?.label ?? 'USA Mobile';
    final customLabelController = TextEditingController(
      text: ['USA Mobile', 'UK Mobile', 'Canada Mobile', 'Personal Mobile', 'Local SIM', 'Work', 'Guardian']
              .contains(selectedLabel)
          ? ''
          : selectedLabel,
    );
    bool isCustomLabel = !['USA Mobile', 'UK Mobile', 'Canada Mobile', 'Personal Mobile', 'Local SIM', 'Work', 'Guardian']
        .contains(selectedLabel);
    if (isCustomLabel) selectedLabel = 'Other';

    bool isWhatsApp = existing?.isWhatsApp ?? false;
    final formKey = GlobalKey<FormState>();

    final presetChips = [
      'USA Mobile',
      'UK Mobile',
      'Canada Mobile',
      'Personal Mobile',
      'Local SIM',
      'Work',
      'Guardian',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_rounded : Icons.add_call,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Contact Number' : 'Add New Contact Number',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '+1 415 555 2671',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          final val = value?.trim() ?? '';
                          if (val.isEmpty) return 'Please enter a phone number';
                          if (val.replaceAll(RegExp(r'\D'), '').length < 6) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimens.gapMd),
                      const Text(
                        'Label / Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: presetChips.map((preset) {
                          final selected = selectedLabel == preset;
                          return ChoiceChip(
                            label: Text(
                              preset,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                color: selected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            selected: selected,
                            selectedColor: AppColors.primary,
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() {
                                  selectedLabel = preset;
                                  isCustomLabel = preset == 'Other';
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      if (isCustomLabel) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: customLabelController,
                          decoration: InputDecoration(
                            labelText: 'Custom Label',
                            hintText: 'e.g. Dubai SIM, Hostel Roommate',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          validator: (value) {
                            if (isCustomLabel && (value == null || value.trim().isEmpty)) {
                              return 'Please enter a custom label';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: AppDimens.gapMd),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.chat_rounded, size: 18, color: AppColors.successGreen),
                                SizedBox(width: 8),
                                Text(
                                  'Also active on WhatsApp',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Switch(
                              value: isWhatsApp,
                              activeThumbColor: AppColors.successGreen,
                              onChanged: (val) => setDialogState(() => isWhatsApp = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final phone = phoneController.text.trim();
                          final effectiveLabel = isCustomLabel
                              ? customLabelController.text.trim()
                              : selectedLabel;

                          setDialogState(() => isSaving = true);
                          try {
                            String id = _resolvedIdentifier ?? widget.student.id;
                            if (isEditing) {
                              final updated = await _repo.updateAdditionalPhone(
                                studentIdentifier: id,
                                contactId: existing.id,
                                phone: phone,
                                label: effectiveLabel,
                                isWhatsApp: isWhatsApp,
                              );
                              // Update SQLite
                              await PhonebookDatabaseService.instance.insertAdditionalPhone(
                                studentId: widget.student.studentId,
                                phone: phone,
                                label: effectiveLabel,
                              );

                              if (mounted) {
                                setState(() {
                                  final idx = _additionalPhones.indexWhere((p) => p.id == existing.id);
                                  if (idx != -1) {
                                    _additionalPhones[idx] = updated;
                                  }
                                });
                              }
                              AppSnackbar.success('Updated', 'Contact updated successfully.');
                            } else {
                              final created = await _repo.addAdditionalPhone(
                                studentIdentifier: id,
                                phone: phone,
                                label: effectiveLabel,
                                isWhatsApp: isWhatsApp,
                              );
                              // Update SQLite
                              await PhonebookDatabaseService.instance.insertAdditionalPhone(
                                studentId: widget.student.studentId,
                                phone: phone,
                                label: effectiveLabel,
                              );

                              if (mounted) {
                                setState(() {
                                  _additionalPhones.add(created);
                                });
                              }
                              AppSnackbar.success('Added', 'New contact number added.');
                            }

                            _notifyUpdated();
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            AppSnackbar.error(
                              'Operation Failed',
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
                      : Text(isEditing ? 'Save Changes' : 'Add Number'),
                ),
              ],
            );
          },
        );
      },
    );
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
                    'Add international phone numbers (e.g. USA, Canada) or update existing contact details.',
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
                    _buildBaseContactTile(
                      label: 'Student Mobile',
                      value: _primaryPhone,
                      icon: Icons.smartphone_rounded,
                      color: AppColors.primary,
                      onEdit: () => _editBaseContact(
                        title: 'Edit Student Mobile',
                        fieldKey: 'primary',
                        currentValue: _primaryPhone,
                      ),
                    ),
                    _buildBaseContactTile(
                      label: 'WhatsApp Number',
                      value: _whatsappNumber,
                      icon: Icons.chat_rounded,
                      color: AppColors.successGreen,
                      onEdit: () => _editBaseContact(
                        title: 'Edit WhatsApp Number',
                        fieldKey: 'whatsapp',
                        currentValue: _whatsappNumber,
                      ),
                    ),
                    _buildBaseContactTile(
                      label: "Father's Phone",
                      value: _fatherPhone,
                      icon: Icons.man_rounded,
                      color: AppColors.secondaryDark,
                      onEdit: () => _editBaseContact(
                        title: "Edit Father's Phone",
                        fieldKey: 'father',
                        currentValue: _fatherPhone,
                      ),
                    ),
                    _buildBaseContactTile(
                      label: "Mother's Phone",
                      value: _motherPhone,
                      icon: Icons.woman_rounded,
                      color: const Color(0xFFDB2777),
                      onEdit: () => _editBaseContact(
                        title: "Edit Mother's Phone",
                        fieldKey: 'mother',
                        currentValue: _motherPhone,
                      ),
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
                      ..._additionalPhones.map(
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
    required VoidCallback onEdit,
  }) {
    final hasVal = value != null && value.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  hasVal ? value : 'Not Set',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: hasVal ? AppColors.textPrimary : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
            onPressed: onEdit,
            tooltip: 'Edit $label',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalPhoneTile(StudentAdditionalPhone phone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: phone.isWhatsApp
                  ? AppColors.successGreen.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              phone.isWhatsApp ? Icons.chat_rounded : Icons.public_rounded,
              color: phone.isWhatsApp ? AppColors.successGreen : AppColors.primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    if (phone.isWhatsApp) ...[
                      const SizedBox(width: 4),
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
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.primary),
            onPressed: () =>
                _showAddOrEditAdditionalPhoneDialog(existing: phone),
            tooltip: 'Edit number',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.cancelledRed),
            onPressed: () => _deleteAdditionalPhone(phone),
            tooltip: 'Delete number',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }
}
