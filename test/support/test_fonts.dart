import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Makes widget tests measure text like a phone.
///
/// The default test font draws every glyph a full em wide, which reports
/// overflows a device never shows. This loads the Flutter SDK's Roboto as the
/// default family and under the names google_fonts gives Plus Jakarta Sans
/// (`PlusJakartaSans_regular`, `PlusJakartaSans_700`, …), and turns off font
/// downloads.
Future<void> loadDeviceLikeFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;

  // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final fonts = Directory('${artifacts.path}/material_fonts');
  if (!fonts.existsSync()) return;

  final bytes = [
    for (final name in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf'])
      if (File('${fonts.path}/$name').existsSync())
        ByteData.sublistView(File('${fonts.path}/$name').readAsBytesSync()),
  ];
  final families = [
    'Roboto',
    'PlusJakartaSans',
    'PlusJakartaSans_regular',
    'PlusJakartaSans_italic',
    for (var w = 100; w <= 900; w += 100) ...['PlusJakartaSans_$w', 'PlusJakartaSans_${w}italic'],
  ];
  for (final family in families) {
    final loader = FontLoader(family);
    for (final b in bytes) {
      loader.addFont(Future.value(b));
    }
    await loader.load();
  }
}
