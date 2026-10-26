import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/responses/staff_users/staff_user.dart';
import '../../../core/utils/validators.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/dropdown_field.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import '../controllers/manage_users_controller.dart';

/// Create (no [user]) or edit a staff user: name, mobile number and role, plus
/// the complaint categories for a complaint solver (all, or only some).
/// There is no password; the person signs in with the number.
class StaffUserFormSheet extends StatefulWidget {
  final StaffUser? user;

  const StaffUserFormSheet({super.key, this.user});

  static Future<void> show({StaffUser? user}) => Get.bottomSheet(
        StaffUserFormSheet(user: user),
        isScrollControlled: true,
      );

  @override
  State<StaffUserFormSheet> createState() => _StaffUserFormSheetState();
}

class _StaffUserFormSheetState extends State<StaffUserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _phone = TextEditingController(text: widget.user?.phoneNumber ?? '');
  late final List<String> _roles = [
    ..._controller.roles,
    // Keep an existing user's role selectable even if the list changed.
    if (widget.user != null && !_controller.roles.contains(widget.user!.role))
      widget.user!.role,
  ];
  late String? _role = widget.user?.role ?? (_roles.isEmpty ? null : _roles.first);

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
      setState(() => _error = 'Pick at least one complaint category, or turn on All categories.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final user = widget.user;
    final categoryIds = _isSolver ? _selectedCategoryIds : null;
    final error = user == null
        ? await _controller.create(name: _name.text, phone: _phone.text, role: _role!, categoryIds: categoryIds)
        : await _controller.edit(user, name: _name.text, phone: _phone.text, role: _role!, categoryIds: categoryIds);
    if (!mounted) return;
    if (error == null) {
      // Not Get.back(): with the success snackbar open it would only close
      // the snackbar.
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  /// Which complaints this solver sees after signing in.
  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Complaint categories', style: AppTextStyles.label),
        const SizedBox(height: AppDimens.gapXs),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('All categories'),
          subtitle: Text(
            _allCategories
                ? 'Sees every complaint'
                : 'Sees only complaints in the categories picked below',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          value: _allCategories,
          onChanged: _saving ? null : (value) => setState(() => _allCategories = value),
        ),
        if (!_allCategories)
          Obx(() {
            final categories = _controller.complaintCategories;
            if (categories.isEmpty) {
              return Text(
                'Complaint categories could not be loaded. Pull to refresh and try again.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.errorRed),
              );
            }
            return Wrap(
              spacing: AppDimens.gapSm,
              runSpacing: AppDimens.gapSm,
              children: [
                for (final category in categories)
                  FilterChip(
                    label: Text(category.name),
                    selected: _categoryIds.contains(category.id),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() {
                              selected ? _categoryIds.add(category.id) : _categoryIds.remove(category.id);
                            }),
                  ),
              ],
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    return SheetScaffold(
      title: isEdit ? 'Edit user' : 'Add user',
      subtitle: 'They sign in with this mobile number. No password is needed.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                label: 'Name',
                hint: 'e.g. Ramesh',
                prefixIcon: Icons.person_outline_rounded,
                validator: ManageUsersController.validateName,
              ),
              const SizedBox(height: AppDimens.gapMd),
              AppTextField(
                controller: _phone,
                label: 'Mobile number',
                hint: '10-digit mobile number',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: Validators.mobile,
              ),
              const SizedBox(height: AppDimens.gapMd),
              DropdownField<String>(
                label: 'Role',
                value: _role,
                items: _roles,
                itemLabel: StaffUser.roleLabelOf,
                enabled: !_saving,
                onChanged: (value) => setState(() => _role = value),
              ),
              if (_isSolver) ...[
                const SizedBox(height: AppDimens.gapMd),
                _buildCategories(),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppDimens.gapMd),
                Container(
                  padding: const EdgeInsets.all(AppDimens.gapMd),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: AppColors.errorRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.errorRed,
                      ),
                      const SizedBox(width: AppDimens.gapSm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.errorRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.gapXl),
              AppButton(
                label: isEdit ? 'Save changes' : 'Create user',
                icon: isEdit ? Icons.save_outlined : Icons.person_add_alt_1_rounded,
                isLoading: _saving,
                onPressed: _role == null ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
