import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/students/pickable_student.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../shared/utils/student_picker_host.dart';
import '../../shared/widgets/student_picker_sheet.dart';
import '../controllers/screen_time_directory_controller.dart';
import 'models.dart';
import 'screen_time_api.dart';
import 'screens/overview_screen.dart';
import 'screens/sessions_screen.dart';
import 'widgets/common.dart';

/// Opens the Screen Time dashboard and curfew sessions from the warden's
/// Screen Time page, wired to the app's API client, groups, tags and the
/// shared student picker (numeric `students.id` only, AGENTS.md §4).
class CurfewAdminEntry {
  CurfewAdminEntry._();

  /// Floor ids for bulk assignment (`students.floor_id`; 0 is the ground floor).
  static const floorIds = [0, 1, 2, 3, 4, 5, 6, 7, 8];

  /// The admin screens' setup (API, floors, groups, tags, student picker).
  static Future<ScreenTimeAdminConfig> adminConfig() async {
    var tags = <int, String>{};
    try {
      final list = await Get.find<TagsRepository>().getTags();
      tags = {for (final t in list) t.id: t.name};
    } catch (_) {
      // Tags are optional for assignment; the other choices still work.
    }
    return ScreenTimeAdminConfig(
      api: ScreenTimeApi(),
      floorOptions: floorIds,
      groupOptions: ScreenTimeDirectoryController.hshGroups.where((g) => g != 'All').toList(),
      tagOptions: tags,
      pickStudents: _pickStudents,
    );
  }

  /// The shared picker sheet; returns the chosen students by numeric id.
  static Future<List<StudentRef>?> _pickStudents(BuildContext context) async {
    final host = _SessionStudentPicker();
    await StudentPickerSheet.show(context, host);
    final picked = host.selectedStudents.toList();
    host.onDelete();
    if (picked.isEmpty) return null;
    return [
      for (final PickableStudent s in picked)
        StudentRef(id: s.id, name: s.name, roomNumber: s.isAlumni ? null : s.room),
    ];
  }

  /// Screen Time home: right now, phones, needs attention, today, 7 days.
  /// Wardens and admins also get the moon icon for curfew sessions; leaders
  /// see their own group only (the server scopes it).
  static Future<void> openOverview(BuildContext context, {required bool canManageSessions}) async {
    final config = await adminConfig();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ScreenTimeOverviewScreen(
        config: config,
        showSessions: canManageSessions,
        onOpenStudentList: (ctx, filter) => Navigator.of(ctx).push(MaterialPageRoute<void>(
          builder: (_) => FilteredStudentsScreen(config: config, filter: filter),
        )),
      ),
    ));
  }

  /// Curfew sessions list (wardens and admins only).
  static Future<void> openSessions(BuildContext context) async {
    final config = await adminConfig();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SessionsScreen(config: config)));
  }
}

class _SessionStudentPicker extends GetxController with StudentPickerHost {
  @override
  final StudentPickerSource studentSource = StudentPickerSource();
}

/// The students behind one overview tile (`GET /screen-time/students?filter=`).
class FilteredStudentsScreen extends StatelessWidget {
  const FilteredStudentsScreen({super.key, required this.config, required this.filter});

  final ScreenTimeAdminConfig config;
  final String filter;

  static const titles = {
    'online': 'Online',
    'quiet': 'Quiet',
    'offline': 'Offline',
    'in_curfew_now': 'In curfew now',
    'using_in_session': 'Using phone in curfew',
    'over_limit': 'Over daily limit',
    'protection_removed': 'Protection removed',
    'locked': 'Locked',
    'no_session': 'Not in any session',
  };

  @override
  Widget build(BuildContext context) {
    return CurfewPage(
      title: titles[filter] ?? 'Students',
      subtitle: 'Tap a student for their summary',
      body: AsyncView<List<Map<String, dynamic>>>(
        load: () async {
          final data = await config.api.students(filter: filter);
          final raw = data['students'] ?? data['data'];
          return raw is List ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
        },
        builder: (context, rows, reload) {
          if (rows.isEmpty) {
            return const EmptyBlock(icon: Icons.people_outline_rounded, title: 'Nobody here');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              final id = studentIdOf(r);
              final status = '${r['connectionStatus'] ?? r['connection_status'] ?? ''}';
              final room = r['roomNumber'] ?? r['room_number'] ?? r['room'];
              final name = '${r['name'] ?? 'Student'}';
              return SurfaceCard(
                onTap: id == null ? null : () => config.openStudent(context, id),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(children: [
                  InitialsAvatar(name: name, status: status.isEmpty ? null : status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                      if (room != null)
                        Text('Room $room', style: const TextStyle(fontSize: 12.5, color: StPalette.textSecondary)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: StPalette.textLight),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
