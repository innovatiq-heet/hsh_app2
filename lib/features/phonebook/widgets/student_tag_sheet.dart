import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../controllers/phonebook_controller.dart';
import '../models/phonebook_models.dart';

class StudentTagSheet extends StatefulWidget {
  final PhonebookStudent student;
  final ValueChanged<List<StudentTag>>? onTagsUpdated;

  const StudentTagSheet({
    super.key,
    required this.student,
    this.onTagsUpdated,
  });

  static Future<List<StudentTag>?> show(
    BuildContext context,
    PhonebookStudent student, {
    ValueChanged<List<StudentTag>>? onTagsUpdated,
  }) {
    return showModalBottomSheet<List<StudentTag>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentTagSheet(
        student: student,
        onTagsUpdated: onTagsUpdated,
      ),
    );
  }

  @override
  State<StudentTagSheet> createState() => _StudentTagSheetState();
}

class _StudentTagSheetState extends State<StudentTagSheet> {
  final TagsRepository _repo = Get.find();
  bool _isLoading = true;
  String? _error;
  int? _resolvedStudentId;

  List<StudentTag> _allTags = [];
  final Set<int> _assignedTagIds = {};
  final List<StudentTag> _currentTags = [];
  final Set<int> _busyTagIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Resolve the numeric students.id. Phonebook ids / bank codes are not
      // students.id, so only the Screen Time directory (or the warden's pick
      // from it) is trusted.
      int? numId = _resolvedStudentId;
      if (numId == null && Get.isRegistered<PhonebookController>()) {
        numId = await Get.find<PhonebookController>().resolveStudentIdForTags(widget.student);
      }
      numId ??= await _pickStudentFromDirectory();

      if (numId == null || numId == 0) {
        throw const ApiException('Could not find this student\'s account. Tap Retry to pick the student.');
      }
      _resolvedStudentId = numId;

      // 2. Fetch all system & custom tags
      final all = await _repo.getTags();
      _allTags = all;

      // 3. Fetch tags currently assigned to this student
      final studentRes = await _repo.getStudentTags(numId);
      _assignedTagIds.clear();
      _currentTags.clear();

      for (final t in studentRes.assignedTags) {
        _assignedTagIds.add(t.id);
        _currentTags.add(t);
      }
      if (studentRes.systemTag != null) {
        _assignedTagIds.add(studentRes.systemTag!.id);
        _currentTags.add(studentRes.systemTag!);
      }

      // Also incorporate tags already stored on PhonebookStudent if not empty
      for (final t in widget.student.tags) {
        _assignedTagIds.add(t.id);
        _currentTags.add(t);
      }
      final unique = dedupeTags(_currentTags);
      _currentTags
        ..clear()
        ..addAll(unique);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Fallback when the phonebook student can't be matched for certain: the
  /// warden picks the right entry from the Screen Time directory (by name).
  Future<int?> _pickStudentFromDirectory() async {
    final page = await ScreenTimeRepository().students(
      limit: 20,
      offset: 0,
      search: widget.student.name.trim(),
    );
    final candidates = page.students
        .whereType<Map>()
        .where((e) => int.tryParse((e['id'] ?? '').toString().trim()) != null)
        .toList();
    if (candidates.isEmpty || !mounted) return null;

    // Same name AND same room, and only one such entry: no need to ask.
    String norm(Object? v) => (v ?? '').toString().trim().toLowerCase();
    final room = norm(widget.student.room);
    if (room.isNotEmpty) {
      final exact = candidates.where((e) =>
          norm(e['name'] ?? e['fullName']) == norm(widget.student.name) &&
          norm(e['room'] ?? e['room_number'] ?? e['roomNumber']) == room);
      if (exact.length == 1) {
        return int.tryParse(exact.first['id'].toString().trim());
      }
    }
    if (candidates.length == 1 &&
        norm(candidates.first['name'] ?? candidates.first['fullName']) ==
            norm(widget.student.name)) {
      return int.tryParse(candidates.first['id'].toString().trim());
    }

    final picked = await showDialog<Map>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select the student'),
        children: [
          for (final c in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text(
                '${c['name'] ?? c['fullName'] ?? 'Student'}'
                '${(c['room'] ?? c['room_number'] ?? c['roomNumber'] ?? '').toString().isEmpty ? '' : ' · Room ${c['room'] ?? c['room_number'] ?? c['roomNumber']}'}',
              ),
            ),
        ],
      ),
    );
    return int.tryParse((picked?['id'] ?? '').toString().trim());
  }

  Future<void> _toggleTag(StudentTag tag) async {
    if (_busyTagIds.contains(tag.id) || _resolvedStudentId == null) return;

    final isAssigned = _assignedTagIds.contains(tag.id);

    // If tag is system tag, cannot be toggled manually
    if (tag.isSystem && isAssigned) {
      AppSnackbar.info('System Tag', '${tag.name} is calculated dynamically by attendance records.');
      return;
    }

    // Limit check: at most 3 manual tags
    if (!isAssigned) {
      final manualCount = _currentTags.where((t) => !t.isSystem).length;
      if (manualCount >= 3) {
        AppSnackbar.warning(
          'Limit Reached',
          'A maximum of 3 manual tags can be assigned per student. Remove an existing tag first.',
        );
        return;
      }
    }

    setState(() => _busyTagIds.add(tag.id));

    try {
      if (isAssigned) {
        await _repo.removeTag(studentId: _resolvedStudentId!, tagId: tag.id);
        _assignedTagIds.remove(tag.id);
        _currentTags.removeWhere((t) => t.id == tag.id);
        AppSnackbar.success('Tag Removed', 'Tag "${tag.name}" removed from ${widget.student.name}.');
      } else {
        await _repo.assignTag(studentId: _resolvedStudentId!, tagId: tag.id);
        _assignedTagIds.add(tag.id);
        _currentTags.add(tag);
        AppSnackbar.success('Tag Assigned', 'Tag "${tag.name}" assigned to ${widget.student.name}.');
      }

      // Sync back with PhonebookController
      if (Get.isRegistered<PhonebookController>()) {
        Get.find<PhonebookController>().updateStudentTagsInList(
          widget.student.id,
          List.from(_currentTags),
        );
      }
      widget.onTagsUpdated?.call(List.from(_currentTags));
    } on ApiException catch (e) {
      AppSnackbar.error('Action Failed', e.message);
    } catch (_) {
      AppSnackbar.error('Action Failed', 'Could not update tag. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busyTagIds.remove(tag.id));
      }
    }
  }

  Future<void> _showCreateTagDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedHex = '#6366f1';

    const colorOptions = [
      '#6366f1', // Indigo
      '#0284c7', // Sky Blue
      '#059669', // Emerald
      '#d97706', // Amber
      '#dc2626', // Red
      '#9333ea', // Purple
      '#ec4899', // Pink
      '#0d9488', // Teal
    ];

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Create New Tag', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tag Name (e.g. Karyakarta, Wing Leader)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Enter tag name',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color Accent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorOptions.map((hex) {
                      final c = StudentTag.parseHexColor(hex);
                      final isSel = selectedHex.toLowerCase() == hex.toLowerCase();
                      return InkWell(
                        onTap: () => setDlgState(() => selectedHex = hex),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSel ? Colors.black : Colors.white, width: isSel ? 2.5 : 1.5),
                          ),
                          child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Description (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Briefly describe this tag',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    AppSnackbar.warning('Validation', 'Please provide a tag name.');
                    return;
                  }
                  try {
                    final newTag = await _repo.createTag(
                      name: name,
                      color: selectedHex,
                      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                    );
                    AppSnackbar.success('Tag Created', 'Created tag "${newTag.name}"');
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } on ApiException catch (e) {
                    AppSnackbar.error('Create Failed', e.message);
                  }
                },
                child: const Text('Create Tag', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );

    if (created == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.label_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Student Tags',
                      style: AppTextStyles.headline.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.student.name,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context, _currentTags),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tap a tag to assign or remove it. Max 3 manual tags per student.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: _allTags.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No tags available yet in the system.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _allTags.map((tag) {
                          final isAssigned = _assignedTagIds.contains(tag.id);
                          final isBusy = _busyTagIds.contains(tag.id);

                          return InkWell(
                            onTap: isBusy ? null : () => _toggleTag(tag),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAssigned ? tag.color : tag.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isAssigned ? tag.color : tag.borderColor,
                                  width: isAssigned ? 1.5 : 1,
                                ),
                                boxShadow: isAssigned
                                    ? [
                                        BoxShadow(
                                          color: tag.color.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isBusy) ...[
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isAssigned ? Colors.white : tag.color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else if (isAssigned) ...[
                                    const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                                    const SizedBox(width: 6),
                                  ] else ...[
                                    Icon(
                                      tag.isSystem ? Icons.auto_awesome_rounded : Icons.label_rounded,
                                      size: 15,
                                      color: tag.color,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    tag.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isAssigned ? Colors.white : tag.color,
                                    ),
                                  ),
                                  if (tag.isSystem) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(System)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isAssigned ? Colors.white70 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions: Create new tag button
            OutlinedButton.icon(
              onPressed: _showCreateTagDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create New Custom Tag', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFFC7D2FE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
