import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'note_model.dart';

class NotesController extends GetxController {
  final notes = <NoteModel>[
    NoteModel(
      id: 'n1',
      title: 'Hostel Room Checklist',
      content:
          '1. Key card & cupboard lock\n2. Laundry basket & detergent\n3. Extension board & study lamp\n4. Water bottle & electric kettle\n5. Bedsheet change on Sunday',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
      isPinned: true,
      folder: 'Hostel',
    ),
    NoteModel(
      id: 'n2',
      title: 'Mid-Term Exam Schedule',
      content:
          '• Data Structures & Algorithms — Monday, 10:00 AM (Room 304)\n• Database Management — Wednesday, 02:00 PM\n• Operating Systems — Friday, 10:00 AM\nNeed to revise Unit 3 & 4 algorithms.',
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      isPinned: true,
      folder: 'Academics',
    ),
    NoteModel(
      id: 'n3',
      title: 'Weekly Laundry Items',
      content:
          '3 pairs of hostel uniform, 2 bedsheets, 1 towel. Drop off before 11:00 AM slot.',
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      isPinned: false,
      folder: 'Hostel',
    ),
    NoteModel(
      id: 'n4',
      title: 'Youth Sabha Discussion Points',
      content:
          'Key takeaways on self-discipline, time management in hostel life, and group ethics.',
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      isPinned: false,
      folder: 'Personal',
    ),
    NoteModel(
      id: 'n5',
      title: 'Semester Project Ideas',
      content:
          'Smart attendance scanner, hostel complaint ticket automation, automated laundry tracker.',
      updatedAt: DateTime.now().subtract(const Duration(days: 6)),
      isPinned: false,
      folder: 'Academics',
    ),
  ].obs;

  final searchQuery = ''.obs;
  final selectedFolder = 'All'.obs;
  final isGridView = false.obs;

  List<String> get folders => const ['All', 'Hostel', 'Academics', 'Personal'];

  List<NoteModel> get filteredNotes {
    var list = notes.toList();
    if (selectedFolder.value != 'All') {
      list = list.where((n) => n.folder == selectedFolder.value).toList();
    }
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where(
            (n) =>
                n.title.toLowerCase().contains(query) ||
                n.content.toLowerCase().contains(query),
          )
          .toList();
    }
    return list;
  }

  List<NoteModel> get pinnedNotes =>
      filteredNotes.where((n) => n.isPinned).toList();

  List<NoteModel> get otherNotes =>
      filteredNotes.where((n) => !n.isPinned).toList();

  void togglePin(String id) {
    final index = notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final item = notes[index];
      notes[index] = item.copyWith(isPinned: !item.isPinned);
    }
  }

  void toggleViewMode() {
    isGridView.value = !isGridView.value;
  }

  NoteModel addNote({String? title, String? content, String? folder}) {
    final targetFolder =
        folder ??
        (selectedFolder.value != 'All' ? selectedFolder.value : 'Hostel');
    final newNote = NoteModel(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Untitled note',
      content: content ?? '',
      updatedAt: DateTime.now(),
      isPinned: false,
      folder: targetFolder,
    );
    notes.insert(0, newNote);
    return newNote;
  }

  void updateNote(
    String id, {
    String? title,
    String? content,
    String? folder,
    bool? isPinned,
  }) {
    final index = notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      notes[index] = notes[index].copyWith(
        title: title,
        content: content,
        folder: folder,
        isPinned: isPinned,
        updatedAt: DateTime.now(),
      );
    }
  }

  void deleteNote(String id) {
    notes.removeWhere((n) => n.id == id);
  }

  /// Formats note timestamps like Apple iOS Notes:
  /// - Today: 10:45 AM
  /// - Yesterday: Yesterday
  /// - Within 7 days: Tuesday
  /// - Older: 15/09/26
  String formatNoteDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(dt.year, dt.month, dt.day);
    final difference = today.difference(noteDate).inDays;

    if (difference == 0) {
      return DateFormat('h:mm a').format(dt);
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7 && difference > 0) {
      return DateFormat('EEEE').format(dt);
    } else {
      return DateFormat('dd/MM/yy').format(dt);
    }
  }
}
