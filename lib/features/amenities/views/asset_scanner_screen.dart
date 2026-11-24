import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../utils/amenity_format.dart';
import 'asset_detail_screen.dart';

/// Scan an asset's QR code (or type its Asset ID) to open it. Any QR text
/// containing `HSH-XXX-00000` works, so the payload can change later.
class AssetScannerScreen extends StatefulWidget {
  final AmenitiesRepository? repository;

  const AssetScannerScreen({super.key, this.repository});

  @override
  State<AssetScannerScreen> createState() => _AssetScannerScreenState();
}

class _AssetScannerScreenState extends State<AssetScannerScreen> {
  late final AmenitiesRepository _repo = widget.repository ?? AmenitiesRepository();
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, facing: CameraFacing.back);
  bool _busy = false;
  String? _lastText;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final text = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (_busy || text == null || text == _lastText) return;
    _lastText = text;
    final code = AmenityFormat.assetCodeIn(text);
    if (code == null) {
      AppSnackbar.warning('Not an HSH Asset', 'This QR code is not an Amenities label.');
      return;
    }
    await _openCode(code);
  }

  Future<void> _openCode(String code) async {
    setState(() => _busy = true);
    try {
      final asset = await _repo.assetByCode(code);
      if (!mounted) return;
      await _scanner.stop();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => AssetDetailScreen(assetId: asset.id)),
      );
    } on ApiException catch (e) {
      AppSnackbar.error('Not Found', e.statusCode == 404 ? 'No item has the code $code.' : e.message);
      _lastText = null;
    } catch (_) {
      AppSnackbar.error('Not Found', "Couldn't look up $code.");
      _lastText = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _typeCode() async {
    final code = await showDialog<String>(context: context, builder: (_) => const _CodeDialog());
    final found = AmenityFormat.assetCodeIn(code);
    if (code == null || !mounted) return;
    if (found == null) {
      AppSnackbar.warning('Asset ID', 'Asset IDs look like HSH-FAN-00124.');
      return;
    }
    await _openCode(found);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan an item'),
        actions: [
          IconButton(tooltip: 'Torch', onPressed: () => _scanner.toggleTorch(), icon: const Icon(Icons.flash_on_rounded)),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _scanner, onDetect: _onDetect),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 2), borderRadius: BorderRadius.circular(20)),
          ),
        ),
        if (_busy) const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: SafeArea(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _typeCode,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.keyboard_rounded),
              label: const Text('Type the Asset ID instead'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Asset ID'),
        content: TextField(
          controller: _text,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'HSH-FAN-00124'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_text.text), child: const Text('Open')),
        ],
      );
}
