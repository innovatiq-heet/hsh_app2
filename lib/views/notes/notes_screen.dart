import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/gradient_header.dart';
import 'note_editor_screen.dart';
import 'note_model.dart';
import 'notes_controller.dart';

class NotesScreen extends GetView<NotesController> {
  const NotesScreen({super.key});

  void _openEditor(String noteId) {
    Get.to(() => NoteEditorScreen(noteId: noteId));
  }

  void _createNewNote() {
    final note = controller.addNote();
    _openEditor(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final searchInputController = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      floatingActionButton: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            onTap: _createNewNote,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  Text(
                    'New note',
                    style: AppTextStyles.button.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Obx(() {
        final pinned = controller.pinnedNotes;
        final others = controller.otherNotes;
        final isGrid = controller.isGridView.value;
        final isSearching = controller.searchQuery.value.isNotEmpty;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Hero Header following the app standard
            SliverGradientHeader(
              overline: 'Personal Space',
              title: 'Notes',
              subtitle: 'Organize your hostel life, studies & thoughts',
              expandedHeight: 220.0,
              leading: Navigator.canPop(context)
                  ? HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Get.back(),
                    )
                  : null,
              actions: [
                HeaderIconButton(
                  icon: isGrid
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_rounded,
                  tooltip: isGrid ? 'List view' : 'Gallery view',
                  onPressed: controller.toggleViewMode,
                ),
              ],
              child: Row(
                children: [
                  HeaderPill(
                    icon: Icons.sticky_note_2_outlined,
                    label: '${controller.notes.length} Notes',
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  if (controller.notes.any((n) => n.isPinned))
                    HeaderPill(
                      icon: Icons.push_pin_rounded,
                      label:
                          '${controller.notes.where((n) => n.isPinned).length} Pinned',
                    ),
                ],
              ),
            ),

            // Top Search Bar & Folder Filter Pills
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapLg,
                  AppDimens.screenPadding,
                  AppDimens.gapSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // iOS-style Rounded Search Field
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppColors.softShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: AppDimens.gapSm),
                          Expanded(
                            child: TextField(
                              controller: searchInputController,
                              style: AppTextStyles.bodyMd.copyWith(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search in notes & checklists...',
                                hintStyle: AppTextStyles.bodyMd.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) =>
                                  controller.searchQuery.value = val,
                            ),
                          ),
                          if (controller.searchQuery.value.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                searchInputController.clear();
                                controller.searchQuery.value = '';
                              },
                              child: const Icon(
                                Icons.cancel_rounded,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),

                    // Folder / Category Pills (All, Hostel, Academics, Personal)
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.folders.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppDimens.gapSm),
                        itemBuilder: (context, idx) {
                          final folder = controller.folders[idx];
                          final isSelected =
                              controller.selectedFolder.value == folder;
                          final count = folder == 'All'
                              ? controller.notes.length
                              : controller.notes
                                  .where((n) => n.folder == folder)
                                  .length;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.selectedFolder.value = folder;
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusPill,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.borderLight,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    folder,
                                    style: AppTextStyles.label.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(
                                        AppDimens.radiusPill,
                                      ),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),
                  ],
                ),
              ),
            ),

            // Empty state if no notes found
            if (pinned.isEmpty && others.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.screenPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.note_alt_outlined,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.gapMd),
                        Text(
                          isSearching ? 'No matching notes' : 'No notes yet',
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isSearching
                              ? 'Try searching with different keywords.'
                              : 'Tap "New note" to capture tasks, study plans & reminders.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  0,
                  AppDimens.screenPadding,
                  100, // Clearance for floating action button
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Pinned Section
                    if (pinned.isNotEmpty) ...[
                      _SectionTitle(
                        icon: Icons.push_pin_rounded,
                        label: 'PINNED',
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: AppDimens.gapSm),
                      if (isGrid)
                        _NotesGrid(notes: pinned, onNoteTap: _openEditor)
                      else
                        _NotesGroupedList(notes: pinned, onNoteTap: _openEditor),
                      const SizedBox(height: AppDimens.gapXl),
                    ],

                    // Other Notes Section
                    if (others.isNotEmpty) ...[
                      if (pinned.isNotEmpty)
                        const _SectionTitle(
                          icon: Icons.notes_rounded,
                          label: 'NOTES',
                          color: AppColors.textMuted,
                        ),
                      if (pinned.isNotEmpty)
                        const SizedBox(height: AppDimens.gapSm),
                      if (isGrid)
                        _NotesGrid(notes: others, onNoteTap: _openEditor)
                      else
                        _NotesGroupedList(notes: others, onNoteTap: _openEditor),
                    ],
                  ]),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS Inset Grouped card container with thin indented dividers
class _NotesGroupedList extends StatelessWidget {
  final List<NoteModel> notes;
  final void Function(String id) onNoteTap;

  const _NotesGroupedList({required this.notes, required this.onNoteTap});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotesController>();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < notes.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.7,
                indent: 18,
                endIndent: 18,
                color: AppColors.borderLight.withValues(alpha: 0.8),
              ),
            Dismissible(
              key: Key(notes[i].id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.cancelledRed,
                  borderRadius: BorderRadius.vertical(
                    top: i == 0
                        ? const Radius.circular(AppDimens.radiusLg)
                        : Radius.zero,
                    bottom: i == notes.length - 1
                        ? const Radius.circular(AppDimens.radiusLg)
                        : Radius.zero,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              onDismissed: (_) {
                controller.deleteNote(notes[i].id);
              },
              child: _NoteListTile(
                note: notes[i],
                onTap: () => onNoteTap(notes[i].id),
                onTogglePin: () => controller.togglePin(notes[i].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Single iOS Notes item row with bold title, timestamp & snippet
class _NoteListTile extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _NoteListTile({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
  });

  Color _getFolderColor(String folder) {
    switch (folder) {
      case 'Hostel':
        return AppColors.primary;
      case 'Academics':
        return const Color(0xFF2563EB); // Blue
      case 'Personal':
        return AppColors.warningOrange;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotesController>();
    final formattedTime = controller.formatNoteDate(note.updatedAt);
    final folderColor = _getFolderColor(note.folder);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Folder Badge
                  Row(
                    children: [
                      if (note.isPinned) ...[
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          note.title,
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: folderColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                        ),
                        child: Text(
                          note.folder,
                          style: TextStyle(
                            color: folderColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Timestamp + Snippet in classic Apple Notes layout
                  Row(
                    children: [
                      Text(
                        formattedTime,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.snippet,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gallery / Grid View (iOS Notes style card grid)
class _NotesGrid extends StatelessWidget {
  final List<NoteModel> notes;
  final void Function(String id) onNoteTap;

  const _NotesGrid({required this.notes, required this.onNoteTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.gapMd,
        crossAxisSpacing: AppDimens.gapMd,
        childAspectRatio: 0.88,
      ),
      itemCount: notes.length,
      itemBuilder: (context, i) {
        final note = notes[i];
        final controller = Get.find<NotesController>();

        return AppCard(
          padding: const EdgeInsets.all(AppDimens.gapMd),
          onTap: () => onNoteTap(note.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pin icon + Folder
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      note.folder,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (note.isPinned)
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.gapSm),

              // Title
              Text(
                note.title,
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Snippet Preview (looks like paper)
              Expanded(
                child: Text(
                  note.content.isEmpty ? 'No text' : note.content,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.fade,
                ),
              ),

              const Divider(height: 12),

              // Date
              Text(
                controller.formatNoteDate(note.updatedAt),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
