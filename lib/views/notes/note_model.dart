/// Purely local — notes are not part of the v2 API contract.
class NoteModel {
  final String id;
  final String title;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.title,
    required this.updatedAt,
  });
}
