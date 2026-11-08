import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/network/responses/staff_users/staff_user.dart';
import '../../../core/utils/validators.dart';
import '../controllers/manage_users_controller.dart';

/// Create (no [user]) or edit a staff user: name, mobile number and role, plus
/// the complaint categories for a complaint solver (all, or only some).
/// There is no password; the person signs in with their verified mobile number.
class StaffUserFormSheet extends StatefulWidget {
  final StaffUser? user;

  const StaffUserFormSheet({super.key, this.user});

  static Future<void> show({StaffUser? user}) => Get.bottomSheet(
        StaffUserFormSheet(user: user),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      );

  @override
  State<StaffUserFormSheet> createState() => _StaffUserFormSheetState();
}

class _StaffUserFormSheetState extends State<StaffUserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _phone =
      TextEditingController(text: widget.user?.phoneNumber ?? '');

  late final List<String> _roles = [
    if (_controller.roles.isNotEmpty)
      ..._controller.roles
    else ...[
      StaffUser.complaintSolverRole,
      'laundry-man',
    ],
    // Keep an existing user's role selectable even if the list changed.
    if (widget.user != null && !_controller.roles.contains(widget.user!.role))
      widget.user!.role,
  ];

  late String? _role =
      widget.user?.role ?? (_roles.isEmpty ? null : _roles.first);

  /// Complaint solver categories: all, or only [_categoryIds].
  late bool _allCategories = widget.user?.categoryIds == null;
  late final Set<int> _categoryIds = {...?widget.user?.categoryIds};

  bool _saving = false;
  String? _error;

  ManageUsersController get _controller => Get.find();

  bool get _isSolver => _role == StaffUser.complaintSolverRole;

  /// What to save: `null` for all categories, else the picked ids in a stable order.
  List<int>? get _selectedCategoryIds =>
      _allCategories ? null : (_categoryIds.toList()..sort());

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _role == null) return;
    if (_isSolver && !_allCategories && _categoryIds.isEmpty) {
      setState(() => _error =
          'Pick at least one complaint category, or turn on All categories.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final user = widget.user;
    final categoryIds = _isSolver ? _selectedCategoryIds : null;
    final error = user == null
        ? await _controller.create(
            name: _name.text,
            phone: _phone.text,
            role: _role!,
            categoryIds: categoryIds,
          )
        : await _controller.edit(
            user,
            name: _name.text,
            phone: _phone.text,
            role: _role!,
            categoryIds: categoryIds,
          );
    if (!mounted) return;
    if (error == null) {
      // In GetX 4, close the modal sheet with Navigator.of(context).pop() so an open
      // snackbar doesn't intercept the close.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.user != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag grab handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Themed Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      isEdit
                          ? Icons.manage_accounts_rounded
                          : Icons.person_add_rounded,
                      size: 24,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Staff User' : 'Add Staff User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit
                              ? 'Update staff permissions & assigned roles'
                              : 'Create a passwordless login for hostel staff',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            // Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Passwordless Info Callout
                      _buildInfoBanner(),
                      const SizedBox(height: 18),

                      // Name Field
                      _buildFieldLabel('Full Name', isRequired: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: ManageUsersController.validateName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: _inputDecoration(
                          hint: 'e.g. Ramesh Bhai',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Mobile Number Field
                      _buildFieldLabel('Mobile Number', isRequired: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phone,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: Validators.mobile,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                        decoration: _inputDecoration(
                          hint: '10-digit mobile number',
                          prefix: Container(
                            margin: const EdgeInsets.only(left: 12, right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '+91',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Themed Role Selection Cards
                      _buildRoleSection(),

                      // Complaint Solver Scope (when role == 'complain-solver')
                      if (_isSolver) ...[
                        const SizedBox(height: 20),
                        _buildCategories(),
                      ],

                      // Error Banner
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(_error!),
                      ],

                      const SizedBox(height: 24),

                      // Action Buttons
                      _buildActionButtons(isEdit),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: const Color(0xFF64748B))
          : null,
      prefix: prefix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.vpn_key_off_rounded, size: 18, color: Color(0xFF0284C7)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Passwordless Sign-In: Staff members log in directly using this verified mobile number. No password setup required.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF0369A1),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Select Staff Role', isRequired: true),
        const SizedBox(height: 8),
        for (final r in _roles) ...[
          Builder(builder: (context) {
            final opt = _RoleOption.of(r);
            final isSelected = _role == r;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: _saving ? null : () => setState(() => _role = r),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? opt.color : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: opt.color.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: opt.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(opt.icon, size: 22, color: opt.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? opt.color
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt.description,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? opt.color : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? opt.color
                                : const Color(0xFFCBD5E1),
                            width: isSelected ? 2 : 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildCategories() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Complaint Categories',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _saving
                ? null
                : () => setState(() => _allCategories = !_allCategories),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _allCategories ? const Color(0xFFEDE9FE) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _allCategories
                      ? const Color(0xFFC4B5FD)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Categories',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _allCategories
                                ? const Color(0xFF6D28D9)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _allCategories
                              ? 'Solver can resolve all hostel complaints'
                              : 'Limited to selected categories below',
                          style: TextStyle(
                            fontSize: 11,
                            color: _allCategories
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _allCategories,
                    activeTrackColor: const Color(0xFF7C3AED),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _allCategories = v),
                  ),
                ],
              ),
            ),
          ),
          if (!_allCategories) ...[
            const SizedBox(height: 12),
            Obx(() {
              final categories = _controller.complaintCategories;
              if (categories.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No categories loaded. Pull to refresh in Manage Users.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Selected ${_categoryIds.length} of ${categories.length} categories',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final cat in categories)
                        Builder(builder: (context) {
                          final isSelected = _categoryIds.contains(cat.id);
                          return InkWell(
                            onTap: _saving
                                ? null
                                : () => setState(() {
                                      if (isSelected) {
                                        _categoryIds.remove(cat.id);
                                      } else {
                                        _categoryIds.add(cat.id);
                                      }
                                    }),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEDE9FE)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFFCBD5E1),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 13,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF6D28D9)
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isEdit) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: const Color(0xFF475569),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF032B4F), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0369A1).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _saving || _role == null ? null : _submit,
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isEdit
                                  ? Icons.save_rounded
                                  : Icons.person_add_alt_1_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEdit ? 'Save Changes' : 'Create Staff User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleOption {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _RoleOption({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  static _RoleOption of(String role) {
    final parsed = UserRoleX.fromApi(role);
    switch (parsed) {
      case UserRole.complainsolver:
        return const _RoleOption(
          key: 'complain-solver',
          label: 'Complaint Solver',
          description:
              'Handles room repairs, electrical, plumbing & carpentry maintenance.',
          icon: Icons.handyman_rounded,
          color: Color(0xFF7C3AED), // Purple
        );
      case UserRole.laundry:
        return const _RoleOption(
          key: 'laundry-man',
          label: 'Laundry Staff',
          description:
              'Processes student laundry bundles, wash cycles & delivery pickup.',
          icon: Icons.local_laundry_service_rounded,
          color: Color(0xFF0284C7), // Sky Blue
        );
      case UserRole.warden:
        return const _RoleOption(
          key: 'warden',
          label: 'Warden / Operator',
          description:
              'Hostel daily operations, curfew management & student oversight.',
          icon: Icons.shield_outlined,
          color: Color(0xFF0369A1), // Deep Navy Blue
        );
      default:
        return _RoleOption(
          key: role,
          label: StaffUser.roleLabelOf(role),
          description: 'Staff member account with mobile number login.',
          icon: Icons.badge_outlined,
          color: const Color(0xFF0D9488), // Teal
        );
    }
  }
}
