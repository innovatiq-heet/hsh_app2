import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/sheet_scaffold.dart';

class ReplaceAssetSheet extends StatefulWidget {
  final SpaceAssetModel oldAsset;
  const ReplaceAssetSheet({super.key, required this.oldAsset});

  @override
  State<ReplaceAssetSheet> createState() => _ReplaceAssetSheetState();
}

class _ReplaceAssetSheetState extends State<ReplaceAssetSheet> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  bool _registerNew = true;
  List<SpaceAssetModel> _candidates = [];
  SpaceAssetModel? _selectedExisting;
  final _reasonCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _mfgCtrl = TextEditingController();
  String _condition = 'new';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _costCtrl.dispose();
    _serialCtrl.dispose();
    _mfgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    try {
      final list = await _repo.listAssets(status: 'working');
      if (mounted) {
        setState(() {
          _candidates = list.where((a) => a.id != widget.oldAsset.id && a.spaceId != widget.oldAsset.spaceId).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _confirm() async {
    if (_reasonCtrl.text.trim().isEmpty || _saving) return;
    if (!_registerNew && _selectedExisting == null) {
      AppSnackbar.warning('Select asset', 'Choose an existing replacement asset or register a new one.');
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await _repo.replaceAsset(widget.oldAsset.id, {
        'reason': _reasonCtrl.text.trim(),
        if (_costCtrl.text.trim().isNotEmpty) 'replacement_cost': double.tryParse(_costCtrl.text.trim()),
        if (!_registerNew && _selectedExisting != null)
          'existing_asset_id': _selectedExisting!.id
        else
          'new_asset': {
            'type_id': widget.oldAsset.typeId,
            'condition': _condition,
            if (_serialCtrl.text.trim().isNotEmpty) 'serial_number': _serialCtrl.text.trim(),
            if (_mfgCtrl.text.trim().isNotEmpty) 'manufacturer': _mfgCtrl.text.trim(),
          },
      });
      final newId = ((res['new_asset'] as Map?)?['asset'] as Map?)?['id'] as num?;
      AppSnackbar.success('Replaced', 'Asset replaced and old history preserved.');
      if (mounted) Navigator.of(context).pop(newId?.toInt() ?? 0);
    } catch (e) {
      AppSnackbar.error('Replacement failed', e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final oldCard = PhonebookCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OLD ASSET', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: PhonebookTheme.red)),
          const SizedBox(height: 4),
          Text(widget.oldAsset.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(widget.oldAsset.assetCode, style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
          Text('${widget.oldAsset.floorName} · ${widget.oldAsset.spaceName}', style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
        ],
      ),
    );

    final newCard = PhonebookCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REPLACEMENT ASSET', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: PhonebookTheme.green)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              PhonebookTintChip(label: 'Register New', selected: _registerNew, onTap: () => setState(() => _registerNew = true)),
              PhonebookTintChip(label: 'Pick Existing', selected: !_registerNew, onTap: () => setState(() => _registerNew = false)),
            ],
          ),
          const SizedBox(height: 10),
          if (_registerNew) ...[
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('New')),
                DropdownMenuItem(value: 'good', child: Text('Good')),
              ],
              onChanged: (v) { if (v != null) setState(() => _condition = v); },
            ),
            const SizedBox(height: 8),
            TextField(controller: _mfgCtrl, decoration: const InputDecoration(labelText: 'Manufacturer (optional)')),
            const SizedBox(height: 8),
            TextField(controller: _serialCtrl, decoration: const InputDecoration(labelText: 'Serial Number (optional)')),
          ] else ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedExisting?.id,
              decoration: const InputDecoration(labelText: 'Select Existing Working Asset'),
              items: [
                for (final c in _candidates)
                  DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.assetCode} · ${c.spaceName})')),
              ],
              onChanged: (v) => setState(() => _selectedExisting = _candidates.firstWhereOrNull((e) => e.id == v)),
            ),
          ],
        ],
      ),
    );

    return SheetScaffold(
      title: 'Replace Asset',
      subtitle: 'Old asset lifecycle history will be preserved',
      children: [
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: oldCard),
              const SizedBox(width: 12),
              Expanded(child: newCard),
            ],
          )
        else ...[
          oldCard,
          const SizedBox(height: 12),
          newCard,
        ],
        const SizedBox(height: 12),
        TextField(controller: _reasonCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Replacement Reason *')),
        const SizedBox(height: 10),
        TextField(
          controller: _costCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Replacement Cost (₹, optional)'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirm,
            child: Text(_saving ? 'Replacing…' : 'Confirm Replacement'),
          ),
        ),
      ],
    );
  }
}
