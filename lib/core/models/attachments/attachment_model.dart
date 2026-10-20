import 'dart:io';

/// A single complaint image. [file] is set for a not-yet-uploaded local
/// pick; [url] is set for a hosted image, with [headers] when the URL needs
/// them (complaint photos need the bearer token).
class AttachmentModel {
  final String? url;
  final File? file;
  final Map<String, String>? headers;

  const AttachmentModel({this.url, this.file, this.headers});

  bool get isLocal => file != null;
}
