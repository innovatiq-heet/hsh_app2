import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../../core/utils/app_snackbar.dart';

/// Pick a student and assign [tag] to them. Students come from the Screen Time
/// directory so the numeric `students.id` is always the identifier sent.
class AssignTagSheet extends StatefulWidget {
  final StudentTag tag;
  final VoidCallback? onAssigned;

  const AssignTagSheet({super.key, required this.tag, this.onAssigned});

  static Future<void> show(
    BuildContext context,
    StudentTag tag, {
    VoidCallback? onAssigned,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignTagSheet(tag: tag, onAssigned: onAssigned),
    );
  }

  @override
  State<AssignTagSheet> createState() => _AssignTagSheetState();
}

class _AssignTagSheetState extends State<AssignTagSheet> {
  final ScreenTimeRepository _students = ScreenTimeRepository();
  final TagsRepository _tags = Get.find();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map> _results = [];
  final Set<int> _assignedIds = {};
  final Set<int> _busyIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String term) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _students.students(limit: 50, offset: 0, search: term);
      if (!mounted || term != _searchCtrl.text.trim()) return;
      _results = page.students.whereType<Map>().toList();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load students.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _assign(Map student) async {
    final id = int.tryParse((student['id'] ?? '').toString().trim());
    final name = (student['name'] ?? student['fullName'] ?? 'Student').toString();
    if (id == null || _busyIds.contains(id) || _assignedIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await _tags.assignTag(studentId: id, tagId: widget.tag.id);
      _assignedIds.add(id);
      widget.onAssigned?.call();
      AppSnackbar.success('Tag Assigned', '"${widget.tag.name}" assigned to $name.');
    } on ApiException catch (e) {
      AppSnackbar.error('Assign Failed', e.message);
    } catch (_) {
      AppSnackbar.error('Assign Failed', 'Could not assign tag. Please try again.');
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Assign "${widget.tag.name}"',
                    style: AppTextStyles.headline.copyWith(fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search student by name, room or code',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
            TextButton(
              onPressed: () => _search(_searchCtrl.text.trim()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No students found.', style: TextStyle(color: Color(0xFF64748B))),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = _results[i];
        final id = int.tryParse((s['id'] ?? '').toString().trim());
        final name = (s['name'] ?? s['fullName'] ?? 'Student').toString();
        final room = (s['room'] ?? s['room_number'] ?? s['roomNumber'] ?? '').toString();
        final done = id != null && _assignedIds.contains(id);
        final busy = id != null && _busyIds.contains(id);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: room.isEmpty ? null : Text('Room $room'),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : done
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669))
                  : TextButton(
                      onPressed: id == null ? null : () => _assign(s),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      child: const Text('Assign'),
                    ),
        );
      },
    );
  }
}
