import 'dart:io';

/// A single complaint image. [file] is set for a not-yet-uploaded local
/// pick; [url] is set once the (future) API returns a hosted path.
class AttachmentModel {
  final String? url;
  final File? file;

  const AttachmentModel({this.url, this.file});

  bool get isLocal => file != null;
}
