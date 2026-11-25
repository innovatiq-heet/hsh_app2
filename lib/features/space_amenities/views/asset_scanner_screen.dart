import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/app_bar_widget.dart';
import '../utils/space_amenity_ui.dart';
import 'asset_details_screen.dart';

class AssetScannerScreen extends StatefulWidget {
  const AssetScannerScreen({super.key});

  @override
  State<AssetScannerScreen> createState() => _AssetScannerScreenState();
}

class _AssetScannerScreenState extends State<AssetScannerScreen> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  final _manualCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup(String raw) async {
    if (_busy) return;
    final code = SpaceAmenityUi.assetCodeIn(raw) ?? raw.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await _repo.assetByCode(code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AssetDetailsScreen(assetId: res.asset.id)),
      );
    } catch (e) {
      AppSnackbar.error('Not found', e.toString());
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Scan Asset QR'),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  final raw = b.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    _lookup(raw);
                    break;
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Or enter Asset ID',
                      hintText: 'HSH-FAN-00001',
                    ),
                    onSubmitted: _lookup,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _busy ? null : () => _lookup(_manualCtrl.text),
                  child: const Text('Find'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
