import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/string_formatting.dart';
import '../utils/student_picker_host.dart';
import 'app_button.dart';
import 'empty_state.dart';

/// Searchable list of students; tapping a row adds or removes them from the
/// host's [StudentPickerHost.selectedStudents].
class StudentPickerSheet extends StatefulWidget {
  final StudentPickerHost controller;

  const StudentPickerSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, StudentPickerHost controller) {
    controller.loadStudents();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentPickerSheet(controller: controller),
    );
  }

  @override
  State<StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<StudentPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  StudentPickerHost get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.gapMd,
              AppDimens.screenPadding,
              AppDimens.gapSm,
            ),
            child: Row(
              children: [
                Expanded(child: Text('Add students', style: AppTextStyles.headline)),
                Obx(() => Text(
                      '${c.selectedStudents.length} selected',
                      style: AppTextStyles.label.copyWith(color: AppColors.primaryLight),
                    )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search name or room',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.gapSm),
          Expanded(
            child: Obx(() {
              if (c.isStudentsLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final error = c.studentsError.value;
              if (error != null) {
                return EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load students',
                  message: error,
                  actionLabel: 'Retry',
                  onAction: () => c.loadStudents(force: true),
                );
              }
              final list = _query.isEmpty
                  ? c.students
                  : c.students
                      .where((s) =>
                          s.name.toLowerCase().contains(_query) ||
                          s.room.toLowerCase().contains(_query))
                      .toList();
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No students found',
                  message: 'Try another name or room.',
                );
              }
              final selected = c.selectedStudents.map((s) => s.id).toSet();
              return ListView.builder(
                itemCount: list.length,
                padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
                itemBuilder: (_, i) {
                  final s = list[i];
                  final isSelected = selected.contains(s.id);
                  final name = formatPersonName(s.name);
                  return ListTile(
                    onTap: () => c.toggleStudent(s),
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? AppColors.primaryLight : AppColors.primarySoft,
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : Text(
                              name.isEmpty ? '#' : name[0].toUpperCase(),
                              style: AppTextStyles.label.copyWith(color: AppColors.primaryLight),
                            ),
                    ),
                    title: Text(name, style: AppTextStyles.subtitle),
                    subtitle: Text('Room ${s.room}', style: AppTextStyles.caption),
                    trailing: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                      color: isSelected ? AppColors.successGreen : AppColors.textLight,
                    ),
                  );
                },
              );
            }),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.gapSm,
                AppDimens.screenPadding,
                AppDimens.gapMd,
              ),
              child: AppButton(
                label: 'Done',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
