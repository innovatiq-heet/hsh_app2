import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/sheet_scaffold.dart';

class TransferAssetSheet extends StatefulWidget {
  final SpaceAssetModel asset;
  const TransferAssetSheet({super.key, required this.asset});

  @override
  State<TransferAssetSheet> createState() => _TransferAssetSheetState();
}

class _TransferAssetSheetState extends State<TransferAssetSheet> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  int _step = 0; // 0: Current, 1: Floor, 2: Space, 3: Reason, 4: Confirm
  List<FloorOverviewItem> _floors = [];
  List<SpaceCardItem> _spaces = [];
  int? _destFloorId;
  SpaceCardItem? _destSpace;
  final _reasonCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFloors();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFloors() async {
    try {
      final ov = await _repo.overview();
      if (mounted) {
        setState(() {
          _floors = ov.floors;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSpacesForFloor(int floorId) async {
    setState(() { _destFloorId = floorId; _destSpace = null; _loading = true; });
    try {
      final fl = await _repo.floorDetails(floorId);
      if (mounted) {
        setState(() {
          _spaces = fl.spaces.where((s) => s.id != widget.asset.spaceId).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_destSpace == null || _reasonCtrl.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _repo.transferAsset(
        widget.asset.id,
        destinationSpaceId: _destSpace!.id,
        reason: _reasonCtrl.text.trim(),
      );
      AppSnackbar.success('Transferred', '${widget.asset.assetCode} moved to ${_destSpace!.name}.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AppSnackbar.error('Transfer failed', e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _canNext {
    if (_step == 1) return _destFloorId != null;
    if (_step == 2) return _destSpace != null;
    if (_step == 3) return _reasonCtrl.text.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Transfer Asset',
      subtitle: 'Step ${_step + 1} of 5 · ${widget.asset.assetCode}',
      children: [
        if (_step == 0) ...[
          PhonebookCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.asset.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Asset ID: ${widget.asset.assetCode}', style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.slate)),
                Text('Current Location: ${widget.asset.floorName} · ${widget.asset.spaceName}', style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.slate)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The asset ID and complete lifecycle history will remain unchanged after transfer.',
            style: TextStyle(fontSize: 12, color: PhonebookTheme.blue, fontWeight: FontWeight.w600),
          ),
        ] else if (_step == 1) ...[
          const Text('Select Destination Floor', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            for (final f in _floors)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _destFloorId == f.floorId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: _destFloorId == f.floorId ? PhonebookTheme.blue : PhonebookTheme.muted,
                ),
                title: Text(f.floorName),
                subtitle: Text('${f.totalSpaces} spaces'),
                onTap: () => _loadSpacesForFloor(f.floorId),
              ),
        ] else if (_step == 2) ...[
          const Text('Select Destination Space', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_spaces.isEmpty)
            const Text('No other active spaces on this floor.')
          else
            for (final sp in _spaces)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _destSpace?.id == sp.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: _destSpace?.id == sp.id ? PhonebookTheme.blue : PhonebookTheme.muted,
                ),
                title: Text(sp.name),
                subtitle: Text(sp.spaceTypeName),
                onTap: () => setState(() => _destSpace = sp),
              ),
        ] else if (_step == 3) ...[
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Transfer Reason *', hintText: 'e.g. Shifted for room renovation'),
          ),
        ] else ...[
          PhonebookCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asset: ${widget.asset.name} (${widget.asset.assetCode})', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('From: ${widget.asset.floorName} · ${widget.asset.spaceName}'),
                Text('To: ${_destSpace?.floorName ?? ''} · ${_destSpace?.name ?? ''}'),
                Text('Reason: ${_reasonCtrl.text.trim()}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Asset ID and lifecycle history will remain unchanged. Inventory counts of both spaces will update immediately.',
            style: TextStyle(fontSize: 12, color: PhonebookTheme.blue, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _step -= 1),
                  child: const Text('Back'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (!_canNext || _saving)
                    ? null
                    : () {
                        if (_step < 4) {
                          setState(() => _step += 1);
                        } else {
                          _confirm();
                        }
                      },
                child: Text(_step < 4 ? 'Continue' : (_saving ? 'Transferring…' : 'Confirm Transfer')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
