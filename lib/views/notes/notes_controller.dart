import 'package:get/get.dart';
import 'note_model.dart';

class NotesController extends GetxController {
  final notes = <NoteModel>[
    NoteModel(
      id: 'n1',
      title: 'Things to buy',
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    NoteModel(
      id: 'n2',
      title: 'Exam schedule',
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ].obs;

  void addNote() {
    notes.insert(
      0,
      NoteModel(
        id: 'n${notes.length + 1}',
        title: 'Untitled note',
        updatedAt: DateTime.now(),
      ),
    );
  }

  void deleteNote(String id) => notes.removeWhere((n) => n.id == id);
}
