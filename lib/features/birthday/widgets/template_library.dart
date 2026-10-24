import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/birthday/birthday_models.dart';
import '../controllers/admin_birthday_controller.dart';

/// Template Studio library: a Students / Parents switch, that audience's saved
/// templates (tap to edit, "Set active", delete) and a "New template" button.
class BirthdayTemplateLibrary extends StatelessWidget {
  final AdminBirthdayController controller;

  const BirthdayTemplateLibrary({super.key, required this.controller});

  static const _accent = Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final audience = controller.editingAudience.value;
      final list = controller.templatesFor(audience);
      final editingId = controller.editingTemplateId.value;
      final target = controller.targetAudience.value;
      final isParent = audience == BirthdayAudience.parent;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AudienceSwitch(
            selected: audience,
            studentCount: controller.templatesFor(BirthdayAudience.student).length,
            parentCount: controller.templatesFor(BirthdayAudience.parent).length,
            onChanged: controller.selectTemplateAudience,
          ),
          const SizedBox(height: 10),
          if (isParent && target == 'student_only')
            const _Note(
              'Parents are not in the Target Audience above, so parent templates are not sent right now.',
            ),
          if (!isParent && target == 'parent_only')
            const _Note(
              'Students are not in the Target Audience above, so automatic sends skip them. '
              'Manual "Send wish" still uses the active student template.',
            ),
          for (final t in list)
            _TemplateTile(
              template: t,
              isActive: controller.isActiveTemplate(t),
              isEditing: t.id == editingId,
              onTap: () => controller.editTemplate(t.id),
              onSetActive: () => controller.setActiveTemplate(t.id),
              onDelete: () => _confirmDelete(context, t),
            ),
          const SizedBox(height: 2),
          OutlinedButton.icon(
            onPressed: controller.addTemplate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(isParent ? 'New parent template' : 'New student template'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: Color(0xFFBAE6FD)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _confirmDelete(BuildContext context, BirthdayTemplate template) async {
    final name = template.name.trim().isEmpty ? 'this template' : '"${template.name.trim()}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete $name? It is removed for good when you save.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.deleteTemplate(template.id);
  }
}

class _AudienceSwitch extends StatelessWidget {
  final String selected;
  final int studentCount;
  final int parentCount;
  final ValueChanged<String> onChanged;

  const _AudienceSwitch({
    required this.selected,
    required this.studentCount,
    required this.parentCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segment(BirthdayAudience.student, Icons.school_rounded, 'Students', studentCount),
          _segment(BirthdayAudience.parent, Icons.family_restroom_rounded, 'Parents', parentCount),
        ],
      ),
    );
  }

  Widget _segment(String value, IconData icon, String label, int count) {
    final isSelected = selected == value;
    final color = isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  '$label · $count',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final BirthdayTemplate template;
  final bool isActive;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  const _TemplateTile({
    required this.template,
    required this.isActive,
    required this.isEditing,
    required this.onTap,
    required this.onSetActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = template.name.trim().isEmpty ? 'Untitled template' : template.name.trim();
    final body = template.body.trim().isEmpty ? 'Empty message' : template.body.trim().replaceAll('\n', ' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isEditing ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isEditing ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                width: isEditing ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, height: 1.3, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (!isActive)
                  TextButton(
                    onPressed: onSetActive,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Set active'),
                  ),
                IconButton(
                  onPressed: isActive ? null : onDelete,
                  tooltip: isActive ? 'The active template can\'t be deleted' : 'Delete template',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.redAccent,
                  disabledColor: const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}
