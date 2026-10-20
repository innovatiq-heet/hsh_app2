/// Upload rules for complaint photos, mirroring the API: JPEG, PNG or WebP
/// (checked by content, not file name), at most 5 MB.
class ImageType {
  ImageType._();

  static const int maxUploadBytes = 5 * 1024 * 1024;

  /// MIME type from the file's first bytes, or `null` if it is not a JPEG,
  /// PNG or WebP (e.g. an iPhone HEIC that was not converted).
  static String? sniffMimeType(List<int> b) {
    if (b.length > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
      return 'image/jpeg';
    }
    const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (b.length > 8 && List.generate(8, (i) => b[i] == png[i]).every((ok) => ok)) {
      return 'image/png';
    }
    if (b.length > 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }
}
