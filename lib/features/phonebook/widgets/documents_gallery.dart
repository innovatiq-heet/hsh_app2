import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/services/student_photo_cache_service.dart';
import '../../../core/utils/student_photo.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/student_contact_card.dart';

/// The documents kept for a student and their parents (Aadhar card, PAN card,
/// signature), shown like the photos: a thumbnail each, tap for full size.
/// Files are found by the student's Aadhar ([familyDocumentUrl]) and kept in
/// the phone's photo cache; a missing one (403/404) is simply not shown.
///
/// Built only when its section is open, so nothing downloads until then.
class DocumentsGallery extends StatefulWidget {
  final String? studentAadhar;
  final String studentName;

  const DocumentsGallery({super.key, required this.studentAadhar, required this.studentName});

  /// Whose documents, in the order shown.
  static const people = [PhotoOf.student, PhotoOf.father, PhotoOf.mother];

  @override
  State<DocumentsGallery> createState() => _DocumentsGalleryState();
}

class _Doc {
  final PhotoOf who;
  final FamilyDocument kind;
  final String url;
  final File file;

  const _Doc(this.who, this.kind, this.url, this.file);
}

class _DocumentsGalleryState extends State<DocumentsGallery> {
  late Future<List<_Doc>> _docs = _load();

  /// [recheck]: forget "not uploaded" answers (kept 7 days) and ask again,
  /// e.g. right after a document was uploaded.
  Future<List<_Doc>> _load({bool recheck = false}) async {
    final cache = StudentPhotoCacheService.instance;
    final jobs = <Future<_Doc?>>[];
    for (final who in DocumentsGallery.people) {
      for (final kind in FamilyDocument.values) {
        final url = familyDocumentUrl(widget.studentAadhar, who, kind);
        if (url == null) continue;
        if (recheck && cache.isMarkedMissing(url)) await cache.invalidate(url);
        jobs.add(StudentPhotoCacheService.instance
            .loadPhoto(url)
            .then((file) => file == null ? null : _Doc(who, kind, url, file))
            .catchError((_) => null));
      }
    }
    return (await Future.wait(jobs)).whereType<_Doc>().toList();
  }

  static String _whoLabel(PhotoOf who) => switch (who) {
        PhotoOf.father => 'Father',
        PhotoOf.mother => 'Mother',
        PhotoOf.student => 'Student',
      };

  @override
  Widget build(BuildContext context) {
    final aadharDigits = (widget.studentAadhar ?? '').replaceAll(RegExp(r'\D'), '');
    if (aadharDigits.length != 12) {
      return const _Empty('No documents available: this student has no Aadhar number saved, which the documents are filed under.');
    }
    return FutureBuilder<List<_Doc>>(
      future: _docs,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final docs = snap.data ?? const <_Doc>[];
        if (docs.isEmpty) {
          return _Empty(
            'No documents available for ${widget.studentName}. Aadhar card, PAN card and signature '
            'show here once they are uploaded.',
            onRetry: () => setState(() => _docs = _load(recheck: true)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final who in DocumentsGallery.people)
              if (docs.any((d) => d.who == who)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(
                    _whoLabel(who),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PhonebookTheme.slate),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final d in docs.where((d) => d.who == who))
                      _Thumb(doc: d, title: '${_whoLabel(who)} · ${d.kind.label}'),
                  ],
                ),
                const SizedBox(height: 6),
              ],
          ],
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final _Doc doc;
  final String title;

  const _Thumb({required this.doc, required this.title});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showStudentPhotoDialog(context, url: doc.url, name: title, localFile: doc.file),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 72,
              decoration: BoxDecoration(
                color: PhonebookTheme.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PhonebookTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                doc.file,
                fit: BoxFit.cover,
                cacheWidth: 288, // decode at thumbnail size
                errorBuilder: (_, _, _) => const Icon(Icons.description_outlined, color: PhonebookTheme.muted),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              doc.kind.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Empty(this.text, {this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.folder_off_outlined, size: 20, color: PhonebookTheme.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.muted, height: 1.35)),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: 'Check again',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20, color: PhonebookTheme.muted),
            ),
        ],
      ),
    );
  }
}
