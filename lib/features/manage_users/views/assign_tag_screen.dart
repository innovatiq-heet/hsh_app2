import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/screentime/screen_time_repository.dart';
import '../../../core/network/repository/tags/tags_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../../phonebook/services/phonebook_database_service.dart';
import '../../phonebook/widgets/alpha_scroll_rail.dart';
import '../../phonebook/widgets/student_tag_sheet.dart';
import '../../../core/network/repository/students/student_picker_source.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/staggered_slide_fade.dart';
import '../../shared/widgets/student_contact_card.dart';

enum TagSortMode {
  roomWise,
  nameAZ,
  assignedFirst,
}

/// Representation of a student capable of being assigned tags.
class TagAssignableStudent {
  final int id;
  final String name;
  final String room;
  final int? floor;
  final String studentCode;
  final String? phone;
  final String? groupName;
  final bool isAlumni;
  final List<StudentTag> tags;

  const TagAssignableStudent({
    required this.id,
    required this.name,
    required this.room,
    this.floor,
    required this.studentCode,
    this.phone,
    this.groupName,
    this.isAlumni = false,
    this.tags = const [],
  });

  bool hasTag(int tagId) => tags.any((t) => t.id == tagId);

  int get manualTagCount => tags.where((t) => !t.isSystem).length;

  TagAssignableStudent copyWith({
    List<StudentTag>? tags,
  }) {
    return TagAssignableStudent(
      id: id,
      name: name,
      room: room,
      floor: floor,
      studentCode: studentCode,
      phone: phone,
      groupName: groupName,
      isAlumni: isAlumni,
      tags: tags ?? this.tags,
    );
  }
}

/// Full screen interface to assign a [StudentTag] to hostel residents and alumni.
///
/// Features:
/// - Natural Room-wise ordering (Ground floor 1-18, Floor 1 101-118, ..., Alumni)
/// - Name A-Z alphabetical ordering with [AlphaScrollRail] fast index
/// - Assigned First quick inspection
/// - Floor filter chips
/// - Real-time student search (name, room, student ID)
/// - Live assign/unassign actions with haptic ticks and SQLite cache synchronization
class AssignTagScreen extends StatefulWidget {
  final StudentTag tag;
  final VoidCallback? onAssigned;

  const AssignTagScreen({
    super.key,
    required this.tag,
    this.onAssigned,
  });

  @override
  State<AssignTagScreen> createState() => _AssignTagScreenState();
}

class _AssignTagScreenState extends State<AssignTagScreen> {
  final TagsRepository _tagsRepo = Get.find<TagsRepository>();
  final ScreenTimeRepository _screenTimeRepo = ScreenTimeRepository();

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ListController _listController = ListController();

  late StudentTag _activeTag;
  List<TagAssignableStudent> _allStudents = [];
  List<TagAssignableStudent> _displayedStudents = [];
  List<StudentTag> _availableTags = [];
  final Set<int> _selectedTagIds = {};

  final Set<int> _busyIds = {};

  /// Tags this screen just changed, per student, kept over the server's list
  /// until the server says its cached list is fresh again
  /// ([TagWriteResult.refreshInSeconds]). Without this, reloading right after
  /// a change showed the old tags again.
  final Map<int, ({List<StudentTag> tags, DateTime until})> _recentTagChanges = {};

  void _rememberChange(int studentId, List<StudentTag> tags, TagWriteResult result) {
    if (result.refreshInSeconds <= 0) {
      _recentTagChanges.remove(studentId);
      return;
    }
    _recentTagChanges[studentId] = (
      tags: List<StudentTag>.of(tags),
      until: DateTime.now().add(Duration(seconds: result.refreshInSeconds + 1)),
    );
  }

  /// [list] with this screen's recent changes on top of the server's (maybe
  /// still cached) tags.
  List<TagAssignableStudent> _withRecentChanges(List<TagAssignableStudent> list) {
    final now = DateTime.now();
    _recentTagChanges.removeWhere((_, change) => change.until.isBefore(now));
    if (_recentTagChanges.isEmpty) return list;
    return [
      for (final s in list)
        if (_recentTagChanges[s.id] case final change?) s.copyWith(tags: change.tags) else s,
    ];
  }

  /// Multi-select: students ticked to get the chosen tags in one go.
  bool _selecting = false;
  bool _bulkBusy = false;
  final Set<int> _pickedIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  TagSortMode _sortMode = TagSortMode.roomWise;
  String _selectedFloor = 'All'; // 'All', '0', '1', ..., '9', 'Alumni'

  // Letter indexing for AlphaScrollRail
  final Map<String, int> _alphaIndex = {};
  final Map<String, int> _alumniAlphaIndex = {};
  List<RailEntry> _railEntries = [];

  // Floor header indexing for Room-wise mode
  final Map<String, int> _floorSectionIndex = {};

  Timer? _debounceTimer;

  static const List<String> _floorOptions = [
    'All',
    'Ground',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'Alumni',
  ];

  @override
  void initState() {
    super.initState();
    _activeTag = widget.tag;
    _selectedTagIds.add(_activeTag.id);
    _availableTags = [_activeTag];
    _loadStudents();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA LOADING
  // ===========================================================================

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all available tags so the user can select multiple tags to assign
      try {
        final allTags = await _tagsRepo.getTags();
        if (allTags.isNotEmpty && mounted) {
          setState(() {
            _availableTags = allTags;
            if (!_availableTags.any((t) => t.id == widget.tag.id)) {
              _availableTags.insert(0, widget.tag);
            }
          });
        }
      } catch (_) {}

      final List<TagAssignableStudent> parsedList = [];

      // 1. Fetch from local phonebook database first to get full student details and group names
      final cached = await PhonebookDatabaseService.instance.searchStudents();
      final cacheByCode = <String, PhonebookStudent>{};
      for (final c in cached) {
        if (c.bankCode != null && c.bankCode!.isNotEmpty) {
          cacheByCode[c.bankCode!] = c;
          final clean = c.bankCode!.replaceFirst(RegExp(r'^0+'), '');
          if (clean.isNotEmpty) cacheByCode[clean] = c;
        }
        if (c.studentId.isNotEmpty) {
          cacheByCode[c.studentId] = c;
          final clean = c.studentId.replaceFirst(RegExp(r'^0+'), '');
          if (clean.isNotEmpty) cacheByCode[clean] = c;
        }
      }

      // 2. Fetch latest student tags & records from backend if possible
      List<Map<String, dynamic>> rawBackend = [];
      try {
        rawBackend = await _tagsRepo.getStudentsForAssignment();
      } catch (_) {}

      // Fallback 1: ScreenTime directory
      if (rawBackend.isEmpty) {
        try {
          final page = await _screenTimeRepo.students(limit: 1000, offset: 0);
          rawBackend = page.students
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        } catch (_) {}
      }

      if (rawBackend.isNotEmpty) {
        for (final m in rawBackend) {
          final rawId = m['student_id'] ?? m['id'];
          final numId = int.tryParse(rawId?.toString() ?? '');
          if (numId == null || numId == 0) continue;

          final studentCode = (m['student_code'] ?? m['bank_code'] ?? '').toString().trim();
          final cleanCode = studentCode.replaceFirst(RegExp(r'^0+'), '');
          final cachedStudent = cacheByCode[studentCode] ?? cacheByCode[cleanCode];

          final name = (m['name'] ?? m['fullName'] ?? cachedStudent?.name ?? 'Student').toString().trim();
          final rawRoom = (m['room_number'] ?? m['room'] ?? cachedStudent?.room ?? '').toString().trim();
          final isAlumni = rawRoom.isEmpty ||
              rawRoom.toLowerCase() == 'alumni' ||
              rawRoom.toLowerCase() == 'n/a' ||
              rawRoom.toLowerCase() == 'none';
          final room = isAlumni ? 'Alumni' : rawRoom;

          int? floor;
          if (!isAlumni) {
            floor = PhonebookStudent.floorOfRoom(room);
          }
          if (floor == null) {
            if (m['floor_id'] != null) {
              floor = int.tryParse(m['floor_id'].toString());
            } else if (m['floorId'] != null) {
              floor = int.tryParse(m['floorId'].toString());
            } else if (cachedStudent?.floor != null) {
              floor = cachedStudent?.floor;
            }
          }

          final phone = m['phone_number']?.toString() ?? m['phone']?.toString() ?? cachedStudent?.primaryPhone;
          final rawGroup = (m['group_name'] ?? m['group'] ?? m['wing'] ?? m['department'] ?? cachedStudent?.groupName)?.toString().trim();
          final groupName = (rawGroup != null && rawGroup.isNotEmpty) ? rawGroup : cachedStudent?.groupName;

          final tagsList = <StudentTag>[];
          if (m['tags'] is List) {
            for (final t in m['tags']) {
              if (t is Map) {
                tagsList.add(StudentTag.fromJson(Map<String, dynamic>.from(t)));
              }
            }
          } else if (cachedStudent != null) {
            tagsList.addAll(cachedStudent.tags);
          }

          parsedList.add(TagAssignableStudent(
            id: numId,
            name: name,
            room: room,
            floor: floor,
            studentCode: studentCode.isNotEmpty ? studentCode : (cachedStudent?.bankCode ?? cachedStudent?.studentId ?? ''),
            phone: phone,
            groupName: groupName,
            isAlumni: isAlumni,
            tags: tagsList,
          ));
        }
      }

      // Fallback 2: PickableStudent directory or cache if rawBackend couldn't be loaded
      if (parsedList.isEmpty) {
        try {
          final pickables = await StudentPickerSource(tags: _tagsRepo, screenTime: _screenTimeRepo).load(includeAlumni: true);
          for (final p in pickables) {
            final cachedStudent = cacheByCode[p.id.toString()];
            final isAlumni = p.isAlumni;
            final room = p.room;
            int? floor;
            if (!isAlumni) {
              floor = PhonebookStudent.floorOfRoom(room);
            }
            parsedList.add(TagAssignableStudent(
              id: p.id,
              name: p.name,
              room: room,
              floor: floor,
              studentCode: cachedStudent?.bankCode ?? cachedStudent?.studentId ?? '',
              phone: cachedStudent?.primaryPhone,
              groupName: cachedStudent?.groupName,
              isAlumni: isAlumni,
              tags: cachedStudent?.tags ?? [],
            ));
          }
        } catch (_) {}
      }

      _allStudents = _withRecentChanges(parsedList);
      _applyFilterAndSort();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException ? e.message : 'Could not load students.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===========================================================================
  // SORTING & FILTERING
  // ===========================================================================

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _applyFilterAndSort();
      }
    });
  }

  void _applyFilterAndSort() {
    final query = _searchCtrl.text.trim().toLowerCase();
    var filtered = List<TagAssignableStudent>.from(_allStudents);

    // 1. Text Search Filter (name, room, student code)
    if (query.isNotEmpty) {
      final cleanNum = query.replaceAll(RegExp(r'\D'), '');
      filtered = filtered.where((s) {
        final matchesName = s.name.toLowerCase().contains(query);
        final matchesRoom = s.room.toLowerCase().contains(query);
        final matchesCode = s.studentCode.toLowerCase().contains(query);
        final matchesPhone = cleanNum.length >= 3 &&
            (s.phone?.replaceAll(RegExp(r'\D'), '').contains(cleanNum) ?? false);
        return matchesName || matchesRoom || matchesCode || matchesPhone;
      }).toList();
    }

    // 2. Floor Filter
    if (_selectedFloor != 'All') {
      if (_selectedFloor == 'Ground') {
        filtered = filtered.where((s) => s.floor == 0 && !s.isAlumni).toList();
      } else if (_selectedFloor == 'Alumni') {
        filtered = filtered.where((s) => s.isAlumni).toList();
      } else {
        final fNum = int.tryParse(_selectedFloor);
        if (fNum != null) {
          filtered = filtered.where((s) => s.floor == fNum && !s.isAlumni).toList();
        }
      }
    }

    // 3. Sorting
    switch (_sortMode) {
      case TagSortMode.roomWise:
        filtered.sort((a, b) => _compareRooms(a, b));
        break;
      case TagSortMode.nameAZ:
        final residents = filtered.where((s) => !s.isAlumni).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final alumni = filtered.where((s) => s.isAlumni).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        filtered = [...residents, ...alumni];
        break;
      case TagSortMode.assignedFirst:
        filtered.sort((a, b) {
          final aAssigned = a.hasTag(widget.tag.id);
          final bAssigned = b.hasTag(widget.tag.id);
          if (aAssigned && !bAssigned) return -1;
          if (!aAssigned && bAssigned) return 1;
          return _compareRooms(a, b);
        });
        break;
    }

    _displayedStudents = filtered;
    _rebuildIndices();

    if (mounted) setState(() {});
  }

  void _rebuildIndices() {
    _alphaIndex.clear();
    _alumniAlphaIndex.clear();
    _floorSectionIndex.clear();

    // Rebuild alphabet index for rail
    for (int i = 0; i < _displayedStudents.length; i++) {
      final s = _displayedStudents[i];
      final letter = _letterOf(s.name);
      if (s.isAlumni) {
        _alumniAlphaIndex.putIfAbsent(letter, () => i);
      } else {
        _alphaIndex.putIfAbsent(letter, () => i);
      }

      // Rebuild floor section index for room-wise headers
      final floorLabel = _floorLabelOf(s);
      _floorSectionIndex.putIfAbsent(floorLabel, () => i);
    }

    final rail = <RailEntry>[];
    for (final l in _alphaIndex.keys) {
      rail.add(RailEntry(l));
    }
    for (final l in _alumniAlphaIndex.keys) {
      rail.add(RailEntry(l, alumni: true));
    }
    _railEntries = rail;
  }

  static String _letterOf(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '#';
    final first = clean[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
  }

  String _floorLabelOf(TagAssignableStudent s) {
    if (s.isAlumni || s.room.toLowerCase() == 'alumni') {
      return 'Alumni & Others';
    }
    final f = s.floor;
    if (f == 0) return 'Ground Floor · Rooms 1–18';
    if (f != null) return 'Floor $f · Rooms ${f}01–${f}18';
    return 'Other Rooms';
  }

  static int _compareRooms(TagAssignableStudent a, TagAssignableStudent b) {
    final aAlumni = a.isAlumni || a.room.toLowerCase() == 'alumni' || a.room.toLowerCase() == 'n/a';
    final bAlumni = b.isAlumni || b.room.toLowerCase() == 'alumni' || b.room.toLowerCase() == 'n/a';

    if (aAlumni && !bAlumni) return 1;
    if (!aAlumni && bAlumni) return -1;
    if (aAlumni && bAlumni) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    final pA = _parseRoom(a.room);
    final pB = _parseRoom(b.room);

    int cmp = pA.number.compareTo(pB.number);
    if (cmp == 0) cmp = pA.suffix.compareTo(pB.suffix);
    if (cmp == 0) cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return cmp;
  }

  static ({int number, String suffix}) _parseRoom(String room) {
    final trimmed = room.trim();
    final match = RegExp(r'^(\d+)(.*)$').firstMatch(trimmed);
    if (match != null) {
      final num = int.tryParse(match.group(1)!) ?? 999999;
      final suffix = match.group(2)?.trim() ?? '';
      return (number: num, suffix: suffix);
    }
    return (number: 999999, suffix: trimmed);
  }

  void _scrollToRailEntry(RailEntry entry) {
    final index = entry.alumni ? _alumniAlphaIndex[entry.letter] : _alphaIndex[entry.letter];
    if (index == null || !_listController.isAttached || !_scrollController.hasClients) return;
    _listController.jumpToItem(
      index: index,
      scrollController: _scrollController,
      alignment: 0,
    );
  }

  void _toggleTagSelection(int tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        if (_selectedTagIds.length > 1) {
          _selectedTagIds.remove(tagId);
        } else {
          AppSnackbar.info('Tag Selection', 'At least one tag must remain selected to assign.');
        }
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  // ===========================================================================
  // MULTI-SELECT
  // ===========================================================================

  void _startSelecting([int? firstId]) {
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      if (firstId != null) _pickedIds.add(firstId);
    });
  }

  void _stopSelecting() {
    setState(() {
      _selecting = false;
      _pickedIds.clear();
    });
  }

  void _togglePicked(int id) {
    setState(() {
      if (!_pickedIds.remove(id)) _pickedIds.add(id);
    });
  }

  /// Ticks everyone currently listed (search and floor filter apply), or
  /// clears them when they are all ticked already.
  void _toggleAllShown() {
    final ids = _displayedStudents.map((s) => s.id);
    setState(() {
      if (ids.every(_pickedIds.contains)) {
        _pickedIds.removeAll(ids);
      } else {
        _pickedIds.addAll(ids);
      }
    });
  }

  /// Gives every ticked student the chosen tags they do not have yet.
  Future<void> _assignToPicked() async {
    if (_bulkBusy || _pickedIds.isEmpty) return;
    final tags = _availableTags.where((t) => _selectedTagIds.contains(t.id)).toList();
    if (tags.isEmpty) return;

    final jobs = <(TagAssignableStudent, List<StudentTag>)>[];
    for (final st in _allStudents.where((s) => _pickedIds.contains(s.id))) {
      final missing = tags.where((t) => !st.hasTag(t.id)).toList();
      if (missing.isNotEmpty) jobs.add((st, missing));
    }
    if (jobs.isEmpty) {
      AppSnackbar.info('Already Assigned', 'The selected students already have these tags.');
      return;
    }

    setState(() => _bulkBusy = true);
    var done = 0;
    var failed = 0;
    String? firstError;
    var wait = TagWriteResult.none;

    Future<void> run((TagAssignableStudent, List<StudentTag>) job) async {
      final (st, missing) = job;
      try {
        final ids = missing.map((t) => t.id).toList();
        final result = ids.length == 1
            ? await _tagsRepo.assignTag(studentId: st.id, tagId: ids.first)
            : await _tagsRepo.assignTags(studentId: st.id, tagIds: ids);
        wait = wait.laterOf(result);
        final updated = [...st.tags, ...missing];
        _rememberChange(st.id, updated, result);
        final i = _allStudents.indexWhere((x) => x.id == st.id);
        if (i != -1) _allStudents[i] = _allStudents[i].copyWith(tags: updated);
        done++;
        try {
          await _updatePhonebookCopy(st, updated);
        } catch (_) {}
      } on ApiException catch (e) {
        failed++;
        firstError ??= e.message;
      } catch (_) {
        failed++;
      }
    }

    // A few at a time: quick, without flooding the server.
    for (var i = 0; i < jobs.length; i += 4) {
      await Future.wait(jobs.skip(i).take(4).map(run));
      if (!mounted) return;
    }

    HapticFeedback.mediumImpact();
    if (done > 0) widget.onAssigned?.call();
    setState(() {
      _bulkBusy = false;
      if (failed == 0) {
        _selecting = false;
        _pickedIds.clear();
      } else {
        // keep the failed ones ticked so they can be retried
        _pickedIds.removeWhere((id) {
          final st = _allStudents.firstWhere((s) => s.id == id);
          return tags.every((t) => st.hasTag(t.id));
        });
      }
    });
    _applyFilterAndSort();

    final tagText = tags.length == 1 ? '"${tags.first.name}"' : '${tags.length} tags';
    if (failed == 0) {
      AppSnackbar.success('Tags Assigned', wait.addTo('$tagText assigned to $done student${done == 1 ? '' : 's'}.'));
    } else {
      AppSnackbar.error(
        'Some Failed',
        '$done assigned, $failed failed${firstError == null ? '' : ': $firstError'}. Failed students stay selected.',
      );
    }
  }

  // ===========================================================================
  // ASSIGN & UNASSIGN ACTIONS
  // ===========================================================================

  /// Keeps the phonebook saved on this phone in step (display only). It is
  /// found by the student's own bank code: a numeric `students.id` must never
  /// be matched against bank codes, where it hit another student ("812" is
  /// also bank code "0812") and left the right one showing a removed tag.
  Future<void> _updatePhonebookCopy(TagAssignableStudent student, List<StudentTag> tags) async {
    final code = student.studentCode.trim();
    if (code.isEmpty) return;
    try {
      await PhonebookDatabaseService.instance.updateStudentTags(code, tags);
    } catch (_) {}
  }

  Future<void> _assignTag(TagAssignableStudent student) async {
    if (_busyIds.contains(student.id)) return;

    // Identify tags in current selection that student does not have yet
    final tagsToAssign = _availableTags
        .where((t) => _selectedTagIds.contains(t.id) && !student.hasTag(t.id))
        .toList();

    // If _availableTags hasn't loaded yet, fall back to widget.tag
    if (tagsToAssign.isEmpty && _availableTags.isEmpty && !student.hasTag(widget.tag.id)) {
      tagsToAssign.add(widget.tag);
    }

    if (tagsToAssign.isEmpty) {
      AppSnackbar.info('Already Assigned', '${student.name} already has all selected tags.');
      return;
    }

    setState(() => _busyIds.add(student.id));

    try {
      final tagIds = tagsToAssign.map((t) => t.id).toList();
      final result = tagIds.length == 1
          ? await _tagsRepo.assignTag(studentId: student.id, tagId: tagIds.first)
          : await _tagsRepo.assignTags(studentId: student.id, tagIds: tagIds);
      HapticFeedback.mediumImpact();

      // Update in memory
      final updatedTags = List<StudentTag>.from(student.tags);
      for (final t in tagsToAssign) {
        if (!updatedTags.any((existing) => existing.id == t.id)) {
          updatedTags.add(t);
        }
      }

      final idxAll = _allStudents.indexWhere((s) => s.id == student.id);
      if (idxAll != -1) {
        _allStudents[idxAll] = _allStudents[idxAll].copyWith(tags: updatedTags);
      }

      final idxDisp = _displayedStudents.indexWhere((s) => s.id == student.id);
      if (idxDisp != -1) {
        _displayedStudents[idxDisp] = _displayedStudents[idxDisp].copyWith(tags: updatedTags);
      }

      _rememberChange(student.id, updatedTags, result);

      // Update SQLite cache
      await _updatePhonebookCopy(student, updatedTags);

      widget.onAssigned?.call();
      final tagNames = tagsToAssign.map((t) => '"${t.name}"').join(', ');
      AppSnackbar.success(
        'Tag${tagsToAssign.length > 1 ? 's' : ''} Assigned',
        result.addTo('$tagNames assigned to ${student.name}.'),
      );
    } on ApiException catch (e) {
      AppSnackbar.error('Assign Failed', e.message);
    } catch (_) {
      AppSnackbar.error('Assign Failed', 'Could not assign tags. Please try again.');
    } finally {
      if (mounted) setState(() => _busyIds.remove(student.id));
    }
  }

  Future<void> _unassignTag(TagAssignableStudent student) async {
    if (_busyIds.contains(student.id)) return;

    // Find removable tags that are in current selection and assigned to student
    final removable = _availableTags
        .where((t) => _selectedTagIds.contains(t.id) && student.hasTag(t.id) && !t.isSystem)
        .toList();

    StudentTag? tagToRemove;
    if (removable.isEmpty) {
      if (student.hasTag(widget.tag.id) && !widget.tag.isSystem) {
        tagToRemove = widget.tag;
      } else {
        return;
      }
    } else if (removable.length == 1) {
      tagToRemove = removable.first;
    } else {
      final picked = await showDialog<StudentTag>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Select Tag to Remove', style: TextStyle(fontWeight: FontWeight.w700)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          children: removable.map((t) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, t),
            child: Row(
              children: [
                Icon(Icons.label_rounded, color: t.color, size: 16),
                const SizedBox(width: 8),
                Text(t.name, style: TextStyle(color: t.color, fontWeight: FontWeight.w700)),
              ],
            ),
          )).toList(),
        ),
      );
      if (picked == null || !mounted) return;
      tagToRemove = picked;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Tag?'),
        content: Text(
          'Remove "${tagToRemove!.name}" from ${student.name}?',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyIds.add(student.id));

    try {
      final result = await _tagsRepo.removeTag(studentId: student.id, tagId: tagToRemove.id);
      HapticFeedback.mediumImpact();

      final updatedTags = List<StudentTag>.from(student.tags)
        ..removeWhere((t) => t.id == tagToRemove!.id);

      final idxAll = _allStudents.indexWhere((s) => s.id == student.id);
      if (idxAll != -1) {
        _allStudents[idxAll] = _allStudents[idxAll].copyWith(tags: updatedTags);
      }

      final idxDisp = _displayedStudents.indexWhere((s) => s.id == student.id);
      if (idxDisp != -1) {
        _displayedStudents[idxDisp] = _displayedStudents[idxDisp].copyWith(tags: updatedTags);
      }

      _rememberChange(student.id, updatedTags, result);
      await _updatePhonebookCopy(student, updatedTags);

      widget.onAssigned?.call();
      AppSnackbar.success(
        'Tag Removed',
        result.addTo('"${tagToRemove.name}" removed from ${student.name}.'),
      );
    } on ApiException catch (e) {
      AppSnackbar.error('Remove Failed', e.message);
    } catch (_) {
      AppSnackbar.error('Remove Failed', 'Could not remove tag. Please try again.');
    } finally {
      if (mounted) setState(() => _busyIds.remove(student.id));
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final showRail = _searchCtrl.text.trim().isEmpty &&
        !_isLoading &&
        _displayedStudents.isNotEmpty &&
        _sortMode == TagSortMode.nameAZ &&
        _railEntries.length > 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: _selecting ? _buildSelectionBar(bottomPad) : null,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildSliverHeader(topPad),
                SliverToBoxAdapter(child: _buildControlsBar()),
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 14),
                          Text(
                            'Loading hostel residents...',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFEF4444)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadStudents,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_displayedStudents.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No students found',
                      message: _searchCtrl.text.isNotEmpty
                          ? 'No students match "${_searchCtrl.text.trim()}".'
                          : 'No students available in this floor or filter.',
                    ),
                  )
                else
                  _buildStudentSuperList(),
                SliverPadding(padding: EdgeInsets.only(bottom: bottomPad + 36)),
              ],
            ),

            // A-Z Scroll Rail overlay (exact phonebook styling)
            if (showRail)
              Positioned(
                right: 4,
                top: topPad + 180,
                bottom: bottomPad + 24,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AlphaScrollRail(
                    entries: _railEntries,
                    onSelected: _scrollToRailEntry,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTagDialog() async {
    final nameCtrl = TextEditingController(text: _activeTag.name);
    final descCtrl = TextEditingController(text: _activeTag.description ?? '');
    String selectedHex = _activeTag.colorHex.isNotEmpty ? _activeTag.colorHex : '#6366f1';
    bool isSaving = false;

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

    final updated = await showDialog<StudentTag>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final currentColor = StudentTag.parseHexColor(selectedHex);
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: currentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_rounded, size: 16, color: currentColor),
                ),
                const SizedBox(width: 10),
                const Text('Edit Tag', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tag Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
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
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          AppSnackbar.warning('Validation', 'Please provide a tag name.');
                          return;
                        }
                        setDlgState(() => isSaving = true);
                        try {
                          final res = await _tagsRepo.updateTag(
                            id: _activeTag.id,
                            name: name,
                            color: selectedHex,
                            description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          );
                          AppSnackbar.success('Tag Updated', _tagsRepo.lastWrite.addTo('Tag "${res.name}" updated successfully.'));
                          if (ctx.mounted) Navigator.pop(ctx, res);
                        } on ApiException catch (e) {
                          AppSnackbar.error('Update Failed', e.message);
                          if (ctx.mounted) setDlgState(() => isSaving = false);
                        } catch (_) {
                          AppSnackbar.error('Update Failed', 'Failed to update tag.');
                          if (ctx.mounted) setDlgState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _activeTag = updated;
        final idx = _availableTags.indexWhere((t) => t.id == updated.id);
        if (idx != -1) {
          _availableTags[idx] = updated;
        }
      });
      widget.onAssigned?.call();
    }
  }

  Widget _buildSliverHeader(double topPad) {
    final assignedCount = _allStudents.where((s) => s.hasTag(widget.tag.id)).length;
    final desc = _activeTag.description?.trim() ?? '';
    return SliverPersistentHeader(
      pinned: true,
      delegate: PhonebookHeaderDelegate(
        overline: 'Assign tag',
        title: _activeTag.name,
        subtitle: desc.isEmpty ? null : desc,
        topPadding: topPad,
        onLeadingTap: () => Navigator.pop(context),
        trailing: _activeTag.isSystem
            ? null
            : PhonebookHeaderCircleButton(
                icon: Icons.edit_rounded,
                tooltip: 'Edit tag',
                onTap: _showEditTagDialog,
              ),
        pills: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            PhonebookHeaderPill(icon: Icons.check_circle_outline_rounded, label: '$assignedCount assigned'),
            if (_selecting) PhonebookHeaderPill(icon: Icons.checklist_rounded, label: '${_pickedIds.length} selected'),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + sort
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search name, room or ID',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applyFilterAndSort();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<TagSortMode>(
                tooltip: 'Sort',
                initialValue: _sortMode,
                onSelected: (mode) {
                  if (_sortMode != mode) {
                    setState(() => _sortMode = mode);
                    _applyFilterAndSort();
                  }
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: TagSortMode.roomWise, child: Text('Room-wise')),
                  PopupMenuItem(value: TagSortMode.nameAZ, child: Text('Name (A-Z)')),
                  PopupMenuItem(value: TagSortMode.assignedFirst, child: Text('Assigned first')),
                ],
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.sort_rounded, size: 20, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tags to give (pick one or several)
          if (_availableTags.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  _selectedTagIds.length > 1 ? 'Tags to assign (${_selectedTagIds.length})' : 'Tag to assign',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                ),
                const Spacer(),
                if (!_selecting)
                  InkWell(
                    onTap: () => _startSelecting(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF0284C7)),
                          SizedBox(width: 4),
                          Text(
                            'Select students',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _availableTags.map((t) {
                  final isSelected = _selectedTagIds.contains(t.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        t.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : t.color,
                        ),
                      ),
                      backgroundColor: t.backgroundColor,
                      selectedColor: t.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? t.color : t.borderColor),
                      ),
                      onSelected: (_) => _toggleTagSelection(t.id),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Floor filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _floorOptions.map((f) {
                final selected = _selectedFloor == f;
                final isAlumni = f == 'Alumni';
                final activeColor = isAlumni ? const Color(0xFF9333EA) : const Color(0xFF0284C7);
                final label = f == 'All'
                    ? 'All'
                    : f == 'Ground'
                        ? 'Ground'
                        : f == 'Alumni'
                            ? 'Alumni'
                            : 'Floor $f';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    selected: selected,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    selectedColor: activeColor,
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: selected ? activeColor : const Color(0xFFE2E8F0)),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedFloor = f);
                        _applyFilterAndSort();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(double bottomPad) {
    final tagCount = _selectedTagIds.length;
    final n = _pickedIds.length;
    final allShown = _displayedStudents.isNotEmpty && _displayedStudents.every((s) => _pickedIds.contains(s.id));
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 12, 8 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            onPressed: _bulkBusy ? null : _stopSelecting,
            icon: const Icon(Icons.close_rounded, color: Color(0xFF475569)),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n selected',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                GestureDetector(
                  onTap: _bulkBusy ? null : _toggleAllShown,
                  child: Text(
                    allShown ? 'Clear shown' : 'Select all shown',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: (n == 0 || _bulkBusy) ? null : _assignToPicked,
            icon: _bulkBusy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.label_rounded, size: 16),
            label: Text(tagCount > 1 ? 'Assign $tagCount tags' : 'Assign tag'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSuperList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      sliver: SuperSliverList(
        listController: _listController,
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final student = _displayedStudents[index];

            // Section Header determination
            Widget? header;
            if (_searchCtrl.text.trim().isEmpty) {
              if (_sortMode == TagSortMode.roomWise) {
                final floorLabel = _floorLabelOf(student);
                if (_floorSectionIndex[floorLabel] == index) {
                  header = _buildFloorSectionHeader(floorLabel);
                }
              } else if (_sortMode == TagSortMode.nameAZ) {
                final letter = _letterOf(student.name);
                final firstIndex = student.isAlumni
                    ? _alumniAlphaIndex[letter]
                    : _alphaIndex[letter];
                if (firstIndex == index) {
                  header = _buildLetterSectionHeader(letter, student.isAlumni);
                }
              }
            }

            final picked = _pickedIds.contains(student.id);
            final card = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _selecting ? null : () => _startSelecting(student.id),
              onTap: _selecting && !_bulkBusy ? () => _togglePicked(student.id) : null,
              // While selecting, a tap anywhere on the card ticks it.
              child: AbsorbPointer(
                absorbing: _selecting,
                child: Stack(
                  children: [
                    _buildStudentCard(student),
                    if (_selecting)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: picked ? const Color(0xFF0284C7).withValues(alpha: 0.06) : null,
                              border: picked ? Border.all(color: const Color(0xFF0284C7), width: 2) : null,
                            ),
                          ),
                        ),
                      ),
                    if (_selecting)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: IgnorePointer(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: picked ? const Color(0xFF0284C7) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: picked ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                width: 1.6,
                              ),
                            ),
                            child: picked ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
            Widget item = card;
            if (header != null) {
              item = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  card,
                ],
              );
            }

            if (index < _displayedStudents.length - 1) {
              item = Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: item,
              );
            }

            if (index < 10) {
              return StaggeredSlideFade(
                index: index,
                duration: const Duration(milliseconds: 220),
                slideOffset: 8.0,
                child: item,
              );
            }
            return item;
          },
          childCount: _displayedStudents.length,
        ),
      ),
    );
  }

  Widget _buildFloorSectionHeader(String label) {
    final isAlumni = label.toLowerCase().contains('alumni');
    final accent = isAlumni ? const Color(0xFF9333EA) : const Color(0xFF0284C7);
    final textAccent = isAlumni ? const Color(0xFF7E22CE) : const Color(0xFF0369A1);

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isAlumni ? Icons.school_rounded : Icons.apartment_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isAlumni ? 'ALUMNI & OTHER STUDENTS' : label.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: textAccent,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterSectionHeader(String letter, bool isAlumni) {
    final accent = isAlumni ? const Color(0xFF9333EA) : const Color(0xFF0284C7);
    final textAccent = isAlumni ? const Color(0xFF7E22CE) : const Color(0xFF0369A1);

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isAlumni
                ? 'Alumni starting with "$letter"'
                : 'Students starting with "$letter"',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textAccent,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStudentTagSheet(TagAssignableStudent student) async {
    final updated = await StudentTagSheet.show(
      context,
      // Keyed by the bank code: the sheet saves tags to the phonebook copy
      // under this id, and a students.id there would hit another student.
      PhonebookStudent(
        id: student.studentCode,
        studentId: student.studentCode,
        name: student.name,
        enrollmentNumber: '',
        department: '',
        batch: '',
        room: student.room,
        floor: student.floor,
        bankCode: student.studentCode,
        tags: student.tags,
        phones: [],
      ),
      studentId: student.id,
      onTagsUpdated: (newTags) {
        // The sheet used the same repository: its last write says how long
        // the server's list may still show the old tags.
        _rememberChange(student.id, newTags, _tagsRepo.lastWrite);
        final idxAll = _allStudents.indexWhere((s) => s.id == student.id);
        if (idxAll != -1) {
          _allStudents[idxAll] = _allStudents[idxAll].copyWith(tags: newTags);
        }
        final idxDisp = _displayedStudents.indexWhere((s) => s.id == student.id);
        if (idxDisp != -1) {
          _displayedStudents[idxDisp] = _displayedStudents[idxDisp].copyWith(tags: newTags);
        }
        if (mounted) setState(() {});
      },
    );
    if (updated != null && mounted) {
      _loadStudents();
    }
  }

  Widget _buildStudentCard(TagAssignableStudent student) {
    final hasAllSelected = _selectedTagIds.isNotEmpty && _selectedTagIds.every((id) => student.hasTag(id));
    final missingSelectedCount = _selectedTagIds.where((id) => !student.hasTag(id)).length;
    final isBusy = _busyIds.contains(student.id);
    final isAlumni = student.isAlumni;

    final gColor = isAlumni ? const Color(0xFF9333EA) : StudentContactCard.groupColor(student.groupName);
    final gBg = isAlumni ? const Color(0xFFF3E8FF) : StudentContactCard.groupBgColor(student.groupName);

    final hasRoom = student.room.isNotEmpty && student.room != 'Alumni' && student.room != 'N/A';
    final group = student.groupName?.trim() ?? '';
    final subtitle = isAlumni
        ? (hasRoom ? 'Alumni · Room ${student.room}' : 'Alumni')
        : [if (hasRoom) 'Room ${student.room}', if (group.isNotEmpty) group].join(' · ');

    final wave = StudentContactCard.waveColor(student.groupName, isAlumni: isAlumni);

    return Container(
      decoration: BoxDecoration(
        color: hasAllSelected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasAllSelected ? const Color(0xFF16A34A).withValues(alpha: 0.4) : const Color(0xFFF1F5F9),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(90, 58),
              painter: CornerWavePainter(color: wave.withValues(alpha: 0.5)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _studentCardBody(
              student: student,
              gColor: gColor,
              gBg: gBg,
              subtitle: subtitle,
              isBusy: isBusy,
              hasAllSelected: hasAllSelected,
              missingSelectedCount: missingSelectedCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentCardBody({
    required TagAssignableStudent student,
    required Color gColor,
    required Color gBg,
    required String subtitle,
    required bool isBusy,
    required bool hasAllSelected,
    required int missingSelectedCount,
  }) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: gBg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                  style: TextStyle(color: gColor, fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: gColor),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isBusy)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              else if (hasAllSelected)
                InkWell(
                  onTap: () => _unassignTag(student),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 15, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'Assigned',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => _assignTag(student),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  child: Text(
                    _selectedTagIds.length > 1 && missingSelectedCount > 0 ? 'Assign ($missingSelectedCount)' : 'Assign',
                  ),
                ),
            ],
          ),
          if (student.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...student.tags.map((t) {
                  final on = _selectedTagIds.contains(t.id);
                  return InkWell(
                    onTap: () => _openStudentTagSheet(student),
                    borderRadius: BorderRadius.circular(8),
                    child: CelebrantLightChip(
                      icon: Icons.label_rounded,
                      text: t.name,
                      bgColor: on ? t.displayColor.withValues(alpha: 0.15) : t.backgroundColor,
                      borderColor: on ? t.displayColor : t.borderColor,
                      textColor: on ? t.displayColor : t.color,
                    ),
                  );
                }),
                InkWell(
                  onTap: () => _openStudentTagSheet(student),
                  borderRadius: BorderRadius.circular(8),
                  child: const CelebrantLightChip(
                    icon: Icons.edit_note_rounded,
                    text: 'Manage',
                    bgColor: Color(0xFFF1F5F9),
                    borderColor: Color(0xFFCBD5E1),
                    textColor: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  onTap: () => _openStudentTagSheet(student),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Manage tags',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            ),
        ],
    );
  }
}
