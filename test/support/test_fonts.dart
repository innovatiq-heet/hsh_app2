import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// For tests that let real async time run while a screen is shown (e.g. to
/// capture a screenshot): google_fonts then tries to load Plus Jakarta Sans,
/// finds no bundled file and throws. This serves Roboto under every Plus
/// Jakarta Sans file name through the asset channel, so the load succeeds.
/// Call after [loadDeviceLikeFonts]; other assets are served from the test
/// asset bundle as usual.
Future<void> serveGoogleFontsAsAssets() async {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final roboto = File('${artifacts.path}/material_fonts/Roboto-Regular.ttf');
  final bundle = Directory('build/unit_test_assets');
  if (!roboto.existsSync() || !bundle.existsSync()) return;
  final robotoBytes = ByteData.sublistView(roboto.readAsBytesSync());

  const codec = StandardMessageCodec();
  final manifestFile = File('${bundle.path}/AssetManifest.bin');
  final manifest = <Object?, Object?>{
    if (manifestFile.existsSync())
      ...codec.decodeMessage(ByteData.sublistView(manifestFile.readAsBytesSync())) as Map<Object?, Object?>,
  };
  const weights = ['Thin', 'ExtraLight', 'Light', 'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'];
  final fontAssets = <String>{
    for (final w in weights) ...[
      'google_fonts/PlusJakartaSans-$w.ttf',
      'google_fonts/PlusJakartaSans-${w == 'Regular' ? '' : w}Italic.ttf',
    ],
  };
  for (final a in fontAssets) {
    manifest[a] = <Object?>[<Object?, Object?>{'asset': a}];
  }
  final manifestBytes = codec.encodeMessage(manifest)!;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
    if (key == 'AssetManifest.bin') return manifestBytes;
    if (fontAssets.contains(key)) return robotoBytes;
    final file = File('${bundle.path}/$key');
    return file.existsSync() ? ByteData.sublistView(file.readAsBytesSync()) : null;
  });
}

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
