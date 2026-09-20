/// Local Note Model for student notes with iOS-style categorization and pinning.
class NoteModel {
  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;
  final bool isPinned;
  final String folder;

  const NoteModel({
    required this.id,
    required this.title,
    this.content = '',
    required this.updatedAt,
    this.isPinned = false,
    this.folder = 'Hostel',
  });

  /// Short preview of the note content (fades into the list tile like iOS Notes)
  String get snippet {
    if (content.trim().isEmpty) return 'No additional text';
    return content.replaceAll('\n', ' ').trim();
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? isPinned,
    String? folder,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      folder: folder ?? this.folder,
    );
  }
}
