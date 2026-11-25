import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/sheet_scaffold.dart';

class AddAmenitySheet extends StatefulWidget {
  final SpaceCardItem space;
  const AddAmenitySheet({super.key, required this.space});

  @override
  State<AddAmenitySheet> createState() => _AddAmenitySheetState();
}

class _AddAmenitySheetState extends State<AddAmenitySheet> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  List<AmenityTypeModel> _types = [];
  bool _loadingTypes = true;
  String _typeSearch = '';
  AmenityTypeModel? _selectedType;
  int _quantity = 1;
  String _condition = 'good';
  DateTime _installDate = DateTime.now();
  bool _showAdvanced = false;
  bool _saving = false;

  final _costCtrl = TextEditingController();
  final _mfgCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<TextEditingController> _perItemSerialCtrls = [TextEditingController()];
  File? _photo;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    _mfgCtrl.dispose();
    _serialCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _perItemSerialCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTypes() async {
    try {
      final cfg = await _repo.config();
      if (mounted) {
        setState(() {
          _types = cfg.types.where((t) => t.isActive).toList();
          if (_types.isNotEmpty) _selectedType = _types.first;
          _loadingTypes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTypes = false);
    }
  }

  void _setQuantity(int next) {
    final q = next.clamp(1, 50);
    setState(() {
      _quantity = q;
      while (_perItemSerialCtrls.length < q) {
        _perItemSerialCtrls.add(TextEditingController());
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedType == null || _saving) return;
    setState(() => _saving = true);
    try {
      String? photoFile;
      if (_photo != null) {
        photoFile = await _repo.uploadPhoto(_photo!);
      }
      final items = [
        for (int i = 0; i < _quantity; i++)
          if (_perItemSerialCtrls[i].text.trim().isNotEmpty) {'serial_number': _perItemSerialCtrls[i].text.trim()} else <String, dynamic>{},
      ];
      await _repo.registerAssetsBulk({
        'space_id': widget.space.id,
        'type_id': _selectedType!.id,
        'quantity': _quantity,
        'condition': _condition,
        'installation_date': _installDate.toIso8601String().slice(0, 10),
        if (_costCtrl.text.trim().isNotEmpty) 'purchase_cost': double.tryParse(_costCtrl.text.trim()),
        if (_mfgCtrl.text.trim().isNotEmpty) 'manufacturer': _mfgCtrl.text.trim(),
        if (_quantity == 1 && _serialCtrl.text.trim().isNotEmpty) 'serial_number': _serialCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'photo_file': ?photoFile,
        if (_quantity > 1) 'items': items,
      });
      AppSnackbar.success('Added', '$_quantity ${_selectedType!.name}${_quantity == 1 ? '' : 's'} registered.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AppSnackbar.error('Registration failed', e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _types.where((t) {
      final q = _typeSearch.trim().toLowerCase();
      return q.isEmpty || t.name.toLowerCase().contains(q) || t.categoryName.toLowerCase().contains(q);
    }).toList();

    return SheetScaffold(
      title: 'Add Amenity',
      subtitle: 'Space: ${widget.space.name}',
      children: [
        if (_loadingTypes)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else ...[
          TextField(
            onChanged: (v) => setState(() => _typeSearch = v),
            decoration: const InputDecoration(
              labelText: 'Search amenity type',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in filtered.take(12))
                PhonebookTintChip(
                  label: t.name,
                  selected: _selectedType?.id == t.id,
                  onTap: () => setState(() => _selectedType = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
              ),
              IconButton(
                onPressed: _quantity > 1 ? () => _setQuantity(_quantity - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text('$_quantity', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: _quantity < 50 ? () => _setQuantity(_quantity + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (_quantity > 1 && _selectedType != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Preview: Will create $_quantity individual ${_selectedType!.name} physical assets (${_selectedType!.codePrefix}-xxxxx).',
                style: const TextStyle(fontSize: 12, color: PhonebookTheme.blue, fontWeight: FontWeight.w600),
              ),
            ),
          DropdownButtonFormField<String>(
            initialValue: _condition,
            decoration: const InputDecoration(labelText: 'Initial Condition'),
            items: const [
              DropdownMenuItem(value: 'new', child: Text('New')),
              DropdownMenuItem(value: 'good', child: Text('Good')),
              DropdownMenuItem(value: 'fair', child: Text('Fair')),
              DropdownMenuItem(value: 'poor', child: Text('Poor')),
            ],
            onChanged: (v) { if (v != null) setState(() => _condition = v); },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Installation Date', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: Text(_installDate.toIso8601String().slice(0, 10)),
            trailing: const Icon(Icons.calendar_today_outlined, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _installDate,
                firstDate: DateTime(2015),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _installDate = picked);
            },
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: _showAdvanced,
            onExpansionChanged: (v) => setState(() => _showAdvanced = v),
            title: const Text('Optional & Advanced Properties', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            children: [
              TextField(
                controller: _costCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Purchase Cost (per item, optional)'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _mfgCtrl, decoration: const InputDecoration(labelText: 'Manufacturer (optional)')),
              const SizedBox(height: 10),
              if (_quantity == 1)
                TextField(controller: _serialCtrl, decoration: const InputDecoration(labelText: 'Serial Number (optional)'))
              else
                for (int i = 0; i < _quantity; i++) ...[
                  TextField(
                    controller: _perItemSerialCtrls[i],
                    decoration: InputDecoration(labelText: 'Item #${i + 1} Serial Number (optional)'),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 10),
              TextField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                  if (picked != null) setState(() => _photo = File(picked.path));
                },
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(_photo == null ? 'Attach Photograph (optional)' : 'Photo selected'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_saving || _selectedType == null) ? null : _submit,
              child: Text(
                _saving ? 'Registering…' : 'Add $_quantity Amenit${_quantity == 1 ? 'y' : 'ies'}',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

extension on String {
  String slice(int start, int end) => substring(start, end);
}
