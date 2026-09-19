import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimens.dart';
import '../../constants/app_text_styles.dart';
import '../../utils/date_formatting.dart';
import '../shared/widgets/empty_state.dart';
import 'note_editor_screen.dart';
import 'notes_controller.dart';

class NotesScreen extends GetView<NotesController> {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Obx(() {
        if (controller.notes.isEmpty) {
          return const EmptyState(
            icon: Icons.note_alt_outlined,
            title: 'No notes yet',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          itemCount: controller.notes.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final note = controller.notes[i];
            return ListTile(
              leading: const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
              ),
              title: Text(note.title, style: AppTextStyles.subtitle),
              subtitle: Text(
                'Edited ${DateFormatting.dateOnly(note.updatedAt.toUtc())}',
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.cancelledRed,
                ),
                onPressed: () => controller.deleteNote(note.id),
              ),
              onTap: () => Get.to(() => NoteEditorScreen(title: note.title)),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
