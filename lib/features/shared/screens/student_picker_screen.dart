import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/students/pickable_student.dart';
import '../../../core/utils/string_formatting.dart';
import '../utils/student_picker_host.dart';
import '../widgets/empty_state.dart';
import '../widgets/phonebook_style_widgets.dart';
import '../widgets/picker_scaffold.dart';
import '../widgets/student_filter_sheet.dart';

/// Filter options for student picker when alumni are included.
enum StudentFilterCategory { all, residents, alumni }

/// Full-screen searchable list of students; tapping a row adds or removes them
/// from the host's [StudentPickerHost.selectedStudents].
class StudentPickerScreen extends StatefulWidget {
  final StudentPickerHost controller;

  const StudentPickerScreen({super.key, required this.controller});

  /// Opens the picker and completes when it is closed.
  static Future<void> open(BuildContext context, StudentPickerHost controller) {
    controller.loadStudents();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StudentPickerScreen(controller: controller)),
    );
  }

  @override
  State<StudentPickerScreen> createState() => _StudentPickerScreenState();
}

class _StudentPickerScreenState extends State<StudentPickerScreen> with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  String _query = '';
  StudentFilterCategory _selectedCategory = StudentFilterCategory.residents;
  StudentFilter _filter = StudentFilter.none;

  /// Slides the new tab's cards in from the side it came from.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  int _slideDirection = 1;

  StudentPickerHost get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _selectCategory(StudentFilterCategory category) {
    if (category == _selectedCategory) return;
    const order = _CategoryTabs.order;
    setState(() {
      _slideDirection = order.indexOf(category) > order.indexOf(_selectedCategory) ? 1 : -1;
      _selectedCategory = category;
    });
    _slide.forward(from: 0);
  }

  /// [step] 1 is the tab to the right, -1 the one to the left; stops at the ends.
  void _swipeCategory(int step) {
    const order = _CategoryTabs.order;
    final next = order.indexOf(_selectedCategory) + step;
    if (next >= 0 && next < order.length) _selectCategory(order[next]);
  }

  void _setQuery(String value) => setState(() => _query = value.trim().toLowerCase());

  void _clearSearch() {
    _search.clear();
    _setQuery('');
  }

  void _clearSelection() {
    for (final s in c.selectedStudents.toList()) {
      c.removeStudent(s);
    }
  }

  /// The students in the chosen tab that match [filter] and the search.
  List<PickableStudent> _visibleStudents(StudentFilter filter) {
    var list = c.students.where(filter.matches);
    if (c.includeAlumniInPicker) {
      if (_selectedCategory == StudentFilterCategory.residents) {
        list = list.where((s) => !s.isAlumni);
      } else if (_selectedCategory == StudentFilterCategory.alumni) {
        list = list.where((s) => s.isAlumni);
      }
    }
    if (_query.isNotEmpty) {
      list = list.where((s) => s.name.toLowerCase().contains(_query) || s.room.toLowerCase().contains(_query));
    }
    return list.toList();
  }

  Future<void> _openFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chosen = await StudentFilterSheet.show(
      context,
      students: c.students.toList(),
      initial: _filter,
      countFor: (f) => _visibleStudents(f).length,
    );
    if (chosen != null && mounted) setState(() => _filter = chosen);
  }

  @override
  Widget build(BuildContext context) {
    return PickerScaffold(
      overline: 'Students',
      title: 'Add students',
      noun: 'student',
      search: _search,
      searchHint: 'Search name or room',
      hasQuery: _query.isNotEmpty,
      onSearchChanged: _setQuery,
      onClearSearch: _clearSearch,
      onRefresh: () => c.loadStudents(force: true),
      onFilterTap: _openFilters,
      activeFilterCount: _filter.count,
      onSwipe: c.includeAlumniInPicker ? _swipeCategory : null,
      filters: c.includeAlumniInPicker
          ? Obx(() {
              final matching = c.students.where(_filter.matches).toList();
              final total = matching.length;
              final alumni = matching.where((s) => s.isAlumni).length;
              return _CategoryTabs(
                selected: _selectedCategory,
                counts: {
                  StudentFilterCategory.all: total,
                  StudentFilterCategory.residents: total - alumni,
                  StudentFilterCategory.alumni: alumni,
                },
                onSelected: _selectCategory,
              );
            })
          : null,
      // Newest first.
      selected: () => [
        for (final s in c.selectedStudents.reversed)
          PickerChip(
            label: formatPersonName(s.name).split(' ').take(2).join(' '),
            onRemove: () => c.removeStudent(s),
          ),
      ],
      onClearSelection: _clearSelection,
      results: _buildResults,
    );
  }

  /// The list, or its loading / error / empty state, as a sliver.
  Widget _buildResults() {
    final loading = c.isStudentsLoading.value;
    // A pull-to-refresh keeps the current list on screen.
    if (loading && c.students.isEmpty) return PickerScaffold.loadingSliver();
    final error = c.studentsError.value;
    if (error != null) {
      return PickerScaffold.messageSliver(EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load students',
        message: error,
        actionLabel: 'Retry',
        onAction: () => c.loadStudents(force: true),
      ));
    }
    final list = _visibleStudents(_filter);
    if (list.isEmpty) {
      final filtered = !_filter.isEmpty;
      return PickerScaffold.messageSliver(EmptyState(
        icon: Icons.person_search_rounded,
        title: 'No students found',
        message: filtered ? 'Try another name, room or filter.' : 'Try another name or room.',
        actionLabel: filtered ? 'Clear filters' : null,
        actionIcon: Icons.filter_alt_off_rounded,
        onAction: filtered ? () => setState(() => _filter = StudentFilter.none) : null,
      ));
    }
    final selected = c.selectedStudents.map((s) => s.id).toSet();
    final progress = _slide.drive(CurveTween(curve: Curves.easeOutCubic));
    final slideIn = progress.drive(Tween(begin: Offset(0.35 * _slideDirection, 0), end: Offset.zero));
    return PickerScaffold.listSliver(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final s = list[i];
        final name = formatPersonName(s.name);
        final alumni = s.isAlumni;
        final tone = alumni ? PhonebookTheme.purple : PhonebookTheme.blue;
        return SlideTransition(
          key: ValueKey(s.id),
          position: slideIn,
          child: FadeTransition(
            opacity: progress,
            child: PickerTile(
              title: name,
              leading: Text(nameInitials(name), style: AppTextStyles.subtitle.copyWith(color: tone, fontSize: 12.5)),
              tone: tone,
              toneSoft: alumni ? PhonebookTheme.purpleSoft : PhonebookTheme.blueSoft,
              badgeIcon: alumni ? Icons.workspace_premium_rounded : Icons.meeting_room_rounded,
              badgeLabel: alumni ? 'Alumni' : 'Room ${s.room}',
              selected: selected.contains(s.id),
              onTap: () => c.toggleStudent(s),
            ),
          ),
        );
      },
    );
  }
}

/// Residents / Alumni / All, each with its count, and a line that slides under
/// the chosen one.
class _CategoryTabs extends StatelessWidget {
  final StudentFilterCategory selected;
  final Map<StudentFilterCategory, int> counts;
  final ValueChanged<StudentFilterCategory> onSelected;

  const _CategoryTabs({required this.selected, required this.counts, required this.onSelected});

  /// In the order shown (and swiped through).
  static const order = [
    StudentFilterCategory.residents,
    StudentFilterCategory.alumni,
    StudentFilterCategory.all,
  ];

  static const _labels = {
    StudentFilterCategory.residents: 'Residents',
    StudentFilterCategory.alumni: 'Alumni',
    StudentFilterCategory.all: 'All',
  };

  @override
  Widget build(BuildContext context) {
    final index = order.indexOf(selected);
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.gapMd),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: PhonebookTheme.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                for (final category in order) Expanded(child: _tab(category, _labels[category]!)),
              ],
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              // -1, 0, 1: under the first, middle and last tab.
              alignment: Alignment(-1 + 2 * index / (order.length - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / order.length,
                child: Container(
                  key: const ValueKey('tab-slider'),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: PhonebookTheme.blue,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(StudentFilterCategory category, String label) {
    final active = category == selected;
    final count = counts[category] ?? 0;
    final color = active ? PhonebookTheme.blue : PhonebookTheme.slate;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(category),
        child: SizedBox(
          height: 40,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.label.copyWith(
                      color: color,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Text(
                      '$count',
                      style: AppTextStyles.caption.copyWith(
                        color: active ? PhonebookTheme.blue : PhonebookTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
