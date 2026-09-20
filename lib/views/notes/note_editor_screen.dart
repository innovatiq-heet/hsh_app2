import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import 'note_model.dart';
import 'notes_controller.dart';

class NoteEditorScreen extends StatefulWidget {
  final String noteId;

  const NoteEditorScreen({super.key, required this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final NotesController _controller;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;

  NoteModel? _currentNote;
  late String _selectedFolder;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<NotesController>();
    _currentNote = _controller.notes.firstWhereOrNull(
      (n) => n.id == widget.noteId,
    );

    _titleController = TextEditingController(
      text: _currentNote?.title == 'Untitled note'
          ? ''
          : (_currentNote?.title ?? ''),
    );
    _contentController = TextEditingController(
      text: _currentNote?.content ?? '',
    );
    _contentFocusNode = FocusNode();

    _selectedFolder = _currentNote?.folder ?? 'Hostel';
    _isPinned = _currentNote?.isPinned ?? false;

    _titleController.addListener(_autoSave);
    _contentController.addListener(_autoSave);
  }

  void _autoSave() {
    final rawTitle = _titleController.text.trim();
    final content = _contentController.text;
    final title = rawTitle.isEmpty ? 'Untitled note' : rawTitle;

    _controller.updateNote(
      widget.noteId,
      title: title,
      content: content,
      folder: _selectedFolder,
      isPinned: _isPinned,
    );
  }

  @override
  void dispose() {
    _titleController.removeListener(_autoSave);
    _contentController.removeListener(_autoSave);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _insertSnippet(String prefix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    // Insert on new line if not at start
    final needsNewLine = start > 0 && text[start - 1] != '\n';
    final insertText = needsNewLine ? '\n$prefix' : prefix;

    final newText = text.replaceRange(start, end, insertText);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );
    _contentFocusNode.requestFocus();
  }

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to permanently delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cancelledRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
            onPressed: () {
              Get.back();
              _controller.deleteNote(widget.noteId);
              Get.back();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = _controller.notes.firstWhereOrNull(
      (n) => n.id == widget.noteId,
    );
    final formattedDate = DateFormat(
      'd MMMM yyyy, h:mm a',
    ).format(note?.updatedAt ?? DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mainBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ],
          ),
          onPressed: () => Get.back(),
          tooltip: 'Notes',
        ),
        titleSpacing: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFolder,
              isDense: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              items: ['Hostel', 'Academics', 'Personal'].map((folder) {
                return DropdownMenuItem<String>(
                  value: folder,
                  child: Text(
                    folder,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedFolder = val);
                  _autoSave();
                }
              },
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _isPinned ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            tooltip: _isPinned ? 'Unpin note' : 'Pin note',
            onPressed: () {
              setState(() => _isPinned = !_isPinned);
              _autoSave();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Delete',
            onPressed: _confirmDelete,
          ),
          const SizedBox(width: AppDimens.gapXs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  AppDimens.gapSm,
                  AppDimens.screenPadding,
                  AppDimens.gapXxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtle timestamp header like Apple Notes
                    Center(
                      child: Text(
                        formattedDate,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapLg),

                    // Borderless large iOS title input
                    TextField(
                      controller: _titleController,
                      style: AppTextStyles.title.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: AppTextStyles.title.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppDimens.gapMd),

                    // Divider line
                    Container(
                      height: 1,
                      color: AppColors.borderLight.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: AppDimens.gapMd),

                    // Borderless rich multi-line note content
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontSize: 16,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Start typing your note...',
                        hintStyle: AppTextStyles.bodyMd.copyWith(
                          fontSize: 16,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // iOS-style formatting & quick insertion toolbar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.screenPadding,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(
                  top: BorderSide(color: AppColors.borderLight),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _ToolbarButton(
                    icon: Icons.check_box_outlined,
                    tooltip: 'Checklist item',
                    onTap: () => _insertSnippet('☑ '),
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  _ToolbarButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'Bullet list',
                    onTap: () => _insertSnippet('• '),
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  _ToolbarButton(
                    icon: Icons.format_list_numbered_rounded,
                    tooltip: 'Numbered list',
                    onTap: () => _insertSnippet('1. '),
                  ),
                  const SizedBox(width: AppDimens.gapSm),
                  _ToolbarButton(
                    icon: Icons.schedule_rounded,
                    tooltip: 'Insert time',
                    onTap: () {
                      final timeStr = DateFormat('h:mm a').format(DateTime.now());
                      _insertSnippet('[$timeStr] ');
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'Done',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mainBackground,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
