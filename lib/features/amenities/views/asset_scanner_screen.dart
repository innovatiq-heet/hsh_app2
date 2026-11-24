import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
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
  bool _torchOn = false;
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

  void _toggleTorch() {
    _scanner.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mobile Scanner Viewport
          MobileScanner(controller: _scanner, onDetect: _onDetect),

          // 2. Translucent Cutout Overlay
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: PhonebookTheme.blue, width: 2.5),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: PhonebookTheme.blue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'Align the asset QR code within the frame',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // 3. Top Executive Action Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  PhonebookHeaderCircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  PhonebookHeaderCircleButton(
                    icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    tooltip: 'Flashlight',
                    onTap: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),

          if (_busy)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: PhonebookTheme.blue),
              ),
            ),

          // 4. Bottom Manual Entry Action
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _typeCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.95),
                  foregroundColor: PhonebookTheme.ink,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.keyboard_rounded, color: PhonebookTheme.blue, size: 20),
                label: const Text(
                  'Enter Asset ID Manually',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ),
            ),
          ),
        ],
      ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: PhonebookTheme.blue, size: 24),
            SizedBox(width: 10),
            Text('Enter Asset ID', style: TextStyle(fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type the code printed on the item label:',
              style: TextStyle(fontSize: 13, color: PhonebookTheme.slate),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: phonebookInputDecoration(
                hint: 'e.g. HSH-FAN-00124',
                prefixIcon: const Icon(Icons.tag_rounded, color: PhonebookTheme.blue),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_text.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: PhonebookTheme.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lookup Asset', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
}
