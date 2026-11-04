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
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/staggered_slide_fade.dart';

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
  final bool isAlumni;
  final List<StudentTag> tags;

  const TagAssignableStudent({
    required this.id,
    required this.name,
    required this.room,
    this.floor,
    required this.studentCode,
    this.phone,
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

  List<TagAssignableStudent> _allStudents = [];
  List<TagAssignableStudent> _displayedStudents = [];

  final Set<int> _busyIds = {};
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
      final List<TagAssignableStudent> parsedList = [];

      // Primary source: backend /students with tag joins
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

          final name = (m['name'] ?? m['fullName'] ?? 'Student').toString().trim();
          final rawRoom = (m['room_number'] ?? m['room'] ?? '').toString().trim();
          final isAlumni = rawRoom.isEmpty ||
              rawRoom.toLowerCase() == 'alumni' ||
              rawRoom.toLowerCase() == 'n/a' ||
              rawRoom.toLowerCase() == 'none';
          final room = isAlumni ? 'Alumni' : rawRoom;

          int? floor;
          if (m['floor_id'] != null) {
            floor = int.tryParse(m['floor_id'].toString());
          } else if (m['floorId'] != null) {
            floor = int.tryParse(m['floorId'].toString());
          } else if (!isAlumni) {
            floor = PhonebookStudent.floorOfRoom(room);
          }

          final studentCode = (m['student_code'] ?? m['bank_code'] ?? '').toString().trim();
          final phone = m['phone_number']?.toString() ?? m['phone']?.toString();

          final tagsList = <StudentTag>[];
          if (m['tags'] is List) {
            for (final t in m['tags']) {
              if (t is Map) {
                tagsList.add(StudentTag.fromJson(Map<String, dynamic>.from(t)));
              }
            }
          }

          parsedList.add(TagAssignableStudent(
            id: numId,
            name: name,
            room: room,
            floor: floor,
            studentCode: studentCode,
            phone: phone,
            isAlumni: isAlumni,
            tags: tagsList,
          ));
        }
      }

      // Fallback 2: Local SQLite cache if backend couldn't be reached
      if (parsedList.isEmpty) {
        final cached = await PhonebookDatabaseService.instance.searchStudents();
        for (final c in cached) {
          final numId = int.tryParse(c.studentId) ?? int.tryParse(c.id);
          if (numId == null || numId == 0) continue;

          parsedList.add(TagAssignableStudent(
            id: numId,
            name: c.name,
            room: c.room ?? (c.isAlumni ? 'Alumni' : 'N/A'),
            floor: c.floor,
            studentCode: c.bankCode ?? c.studentId,
            phone: c.primaryPhone,
            isAlumni: c.isAlumni,
            tags: c.tags,
          ));
        }
      }

      _allStudents = parsedList;
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

  // ===========================================================================
  // ASSIGN & UNASSIGN ACTIONS
  // ===========================================================================

  Future<void> _assignTag(TagAssignableStudent student) async {
    if (_busyIds.contains(student.id)) return;

    if (student.manualTagCount >= 3) {
      AppSnackbar.warning(
        'Limit Reached',
        '${student.name} already has the maximum of 3 manual tags. Please remove one before adding another.',
      );
      return;
    }

    setState(() => _busyIds.add(student.id));

    try {
      await _tagsRepo.assignTag(studentId: student.id, tagId: widget.tag.id);
      HapticFeedback.mediumImpact();

      // Update in memory
      final updatedTags = List<StudentTag>.from(student.tags);
      if (!updatedTags.any((t) => t.id == widget.tag.id)) {
        updatedTags.add(widget.tag);
      }

      final idxAll = _allStudents.indexWhere((s) => s.id == student.id);
      if (idxAll != -1) {
        _allStudents[idxAll] = _allStudents[idxAll].copyWith(tags: updatedTags);
      }

      final idxDisp = _displayedStudents.indexWhere((s) => s.id == student.id);
      if (idxDisp != -1) {
        _displayedStudents[idxDisp] = _displayedStudents[idxDisp].copyWith(tags: updatedTags);
      }

      // Update SQLite cache
      await PhonebookDatabaseService.instance.updateStudentTags(
        student.id.toString(),
        updatedTags,
      );

      widget.onAssigned?.call();
      AppSnackbar.success(
        'Tag Assigned',
        '"${widget.tag.name}" assigned to ${student.name}.',
      );
    } on ApiException catch (e) {
      AppSnackbar.error('Assign Failed', e.message);
    } catch (_) {
      AppSnackbar.error('Assign Failed', 'Could not assign tag. Please try again.');
    } finally {
      if (mounted) setState(() => _busyIds.remove(student.id));
    }
  }

  Future<void> _unassignTag(TagAssignableStudent student) async {
    if (_busyIds.contains(student.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Tag?'),
        content: Text(
          'Remove "${widget.tag.name}" from ${student.name}?',
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
      await _tagsRepo.removeTag(studentId: student.id, tagId: widget.tag.id);
      HapticFeedback.mediumImpact();

      final updatedTags = List<StudentTag>.from(student.tags)
        ..removeWhere((t) => t.id == widget.tag.id);

      final idxAll = _allStudents.indexWhere((s) => s.id == student.id);
      if (idxAll != -1) {
        _allStudents[idxAll] = _allStudents[idxAll].copyWith(tags: updatedTags);
      }

      final idxDisp = _displayedStudents.indexWhere((s) => s.id == student.id);
      if (idxDisp != -1) {
        _displayedStudents[idxDisp] = _displayedStudents[idxDisp].copyWith(tags: updatedTags);
      }

      await PhonebookDatabaseService.instance.updateStudentTags(
        student.id.toString(),
        updatedTags,
      );

      widget.onAssigned?.call();
      AppSnackbar.success(
        'Tag Removed',
        '"${widget.tag.name}" removed from ${student.name}.',
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

  Widget _buildSliverHeader(double topPad) {
    final assignedCount = _allStudents.where((s) => s.hasTag(widget.tag.id)).length;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      expandedHeight: topPad + 130,
      backgroundColor: widget.tag.displayColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F172A),
                widget.tag.displayColor,
                widget.tag.displayColor.withValues(alpha: 0.85),
              ],
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, topPad + 48, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.label_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          widget.tag.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$assignedCount Assigned',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Assign "${widget.tag.name}" Tag',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              if (widget.tag.description != null && widget.tag.description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.tag.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by student name, room (e.g. 204), or ID',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 21),
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
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Sorting Segmented Control
          Row(
            children: [
              _buildSortChip(
                mode: TagSortMode.roomWise,
                label: 'Room-wise',
                icon: Icons.meeting_room_outlined,
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                mode: TagSortMode.nameAZ,
                label: 'Name (A-Z)',
                icon: Icons.sort_by_alpha_rounded,
              ),
              const SizedBox(width: 8),
              _buildSortChip(
                mode: TagSortMode.assignedFirst,
                label: 'Assigned First',
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Floor Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _floorOptions.map((f) {
                final selected = _selectedFloor == f;
                String displayLabel = f;
                if (f == 'All') {
                  displayLabel = 'All Rooms';
                } else if (f == 'Ground') {
                  displayLabel = 'Ground Floor';
                } else if (f != 'Alumni') {
                  displayLabel = 'Floor $f';
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      displayLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    backgroundColor: const Color(0xFFF8FAFC),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
                      ),
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

  Widget _buildSortChip({
    required TagSortMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _sortMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_sortMode != mode) {
            setState(() => _sortMode = mode);
            _applyFilterAndSort();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
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

            final card = _buildStudentCard(student);
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
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.apartment_rounded, size: 16, color: Color(0xFF475569)),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterSectionHeader(String letter, bool isAlumni) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isAlumni ? const Color(0xFF9333EA) : AppColors.primary).withValues(alpha: 0.12),
            (isAlumni ? const Color(0xFF9333EA) : AppColors.primary).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isAlumni ? const Color(0xFF9333EA) : AppColors.primary).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isAlumni ? const Color(0xFF9333EA) : AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAlumni ? 'Alumni' : 'Residents',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isAlumni ? const Color(0xFF9333EA) : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(TagAssignableStudent student) {
    final hasCurrentTag = student.hasTag(widget.tag.id);
    final isBusy = _busyIds.contains(student.id);
    final isAlumni = student.isAlumni;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasCurrentTag
              ? widget.tag.displayColor.withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
          width: hasCurrentTag ? 1.5 : 1,
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
        children: [
          // Room Badge
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isAlumni ? const Color(0xFFFAF5FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAlumni ? const Color(0xFFE9D5FF) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAlumni ? Icons.school_rounded : Icons.meeting_room_rounded,
                  size: 15,
                  color: isAlumni ? const Color(0xFF9333EA) : AppColors.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  student.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isAlumni ? 9 : 12,
                    fontWeight: FontWeight.w800,
                    color: isAlumni ? const Color(0xFF9333EA) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (!isAlumni && student.floor != null) ...[
                      Text(
                        student.floor == 0 ? 'Ground Floor' : 'Floor ${student.floor}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                    if (student.studentCode.isNotEmpty)
                      Text(
                        student.studentCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
                if (student.tags.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: student.tags.map((t) {
                      final isThisTag = t.id == widget.tag.id;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isThisTag
                              ? widget.tag.displayColor
                              : t.displayColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isThisTag
                                ? widget.tag.displayColor
                                : t.displayColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isThisTag ? Colors.white : t.displayColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Button
          if (isBusy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (hasCurrentTag)
            InkWell(
              onTap: () => _unassignTag(student),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'Assigned',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (student.manualTagCount >= 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Max 3 Tags',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _assignTag(student),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.tag.displayColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Assign',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
