import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/tags/student_tag_model.dart';
import '../widgets/empty_state.dart';
import '../widgets/phonebook_style_widgets.dart';
import '../widgets/picker_scaffold.dart';

/// Full-screen searchable list of student tags; tapping a row calls
/// [onToggle], which adds it to or removes it from [selectedIds].
class TagPickerScreen extends StatefulWidget {
  final RxList<StudentTag> tags;
  final RxSet<int> selectedIds;
  final RxBool isLoading;
  final ValueChanged<int> onToggle;
  final Future<void> Function() onRefresh;

  const TagPickerScreen({
    super.key,
    required this.tags,
    required this.selectedIds,
    required this.isLoading,
    required this.onToggle,
    required this.onRefresh,
  });

  /// Opens the picker and completes when it is closed.
  static Future<void> open(
    BuildContext context, {
    required RxList<StudentTag> tags,
    required RxSet<int> selectedIds,
    required RxBool isLoading,
    required ValueChanged<int> onToggle,
    required Future<void> Function() onRefresh,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TagPickerScreen(
          tags: tags,
          selectedIds: selectedIds,
          isLoading: isLoading,
          onToggle: onToggle,
          onRefresh: onRefresh,
        ),
      ),
    );
  }

  @override
  State<TagPickerScreen> createState() => _TagPickerScreenState();
}

class _TagPickerScreenState extends State<TagPickerScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() => _query = value.trim().toLowerCase());

  void _clearSearch() {
    _search.clear();
    _setQuery('');
  }

  void _clearSelection() {
    for (final id in widget.selectedIds.toList()) {
      widget.onToggle(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PickerScaffold(
      overline: 'Student tags',
      title: 'Add tags',
      noun: 'tag',
      search: _search,
      searchHint: 'Search tags',
      hasQuery: _query.isNotEmpty,
      onSearchChanged: _setQuery,
      onClearSearch: _clearSearch,
      onRefresh: widget.onRefresh,
      selected: () => [
        for (final t in widget.tags)
          if (widget.selectedIds.contains(t.id))
            PickerChip(label: t.name, onRemove: () => widget.onToggle(t.id)),
      ],
      onClearSelection: _clearSelection,
      results: _buildResults,
    );
  }

  Widget _buildResults() {
    final loading = widget.isLoading.value;
    // A pull-to-refresh keeps the current list on screen.
    if (loading && widget.tags.isEmpty) return PickerScaffold.loadingSliver();
    if (widget.tags.isEmpty) {
      return PickerScaffold.messageSliver(const EmptyState(
        icon: Icons.sell_outlined,
        title: 'No tags yet',
        message: 'Create them in Student Tags, or add students individually.',
      ));
    }
    final list = widget.tags.where((t) => t.name.toLowerCase().contains(_query)).toList();
    if (list.isEmpty) {
      return PickerScaffold.messageSliver(const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No tags found',
        message: 'Try another name.',
      ));
    }
    final selected = widget.selectedIds.toSet();
    return PickerScaffold.listSliver(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final t = list[i];
        return PickerTile(
          key: ValueKey(t.id),
          title: t.name,
          leading: Icon(Icons.sell_rounded, size: 21, color: t.color),
          tone: t.color,
          toneSoft: t.backgroundColor,
          badgeIcon: Icons.groups_rounded,
          badgeLabel: '${t.studentCount} ${t.studentCount == 1 ? 'student' : 'students'}',
          badgeTextColor: PhonebookTheme.slate,
          selected: selected.contains(t.id),
          onTap: () => widget.onToggle(t.id),
        );
      },
    );
  }
}
