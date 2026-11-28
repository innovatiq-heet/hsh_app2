import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/space_amenities/space_amenity_models.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/sheet_scaffold.dart';

class SpaceEditorSheet extends StatefulWidget {
  final int floorId;
  final List<SpaceTypeModel> spaceTypes;
  final SpaceCardItem? existing;

  const SpaceEditorSheet({
    super.key,
    required this.floorId,
    required this.spaceTypes,
    this.existing,
  });

  @override
  State<SpaceEditorSheet> createState() => _SpaceEditorSheetState();
}

class _SpaceEditorSheetState extends State<SpaceEditorSheet> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _room = TextEditingController(text: widget.existing?.roomNumber ?? '');
  late final TextEditingController _cap = TextEditingController(text: widget.existing?.capacity?.toString() ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.existing?.description ?? '');
  late int _typeId = widget.existing?.spaceTypeId ?? (widget.spaceTypes.isNotEmpty ? widget.spaceTypes.first.id : 1);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    _cap.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final name = _name.text.trim();
      final room = _room.text.trim();
      final capacity = int.tryParse(_cap.text.trim());
      final description = _desc.text.trim();

      if (widget.existing == null) {
        await _repo.createSpace({
          'floor_id': widget.floorId,
          'space_type_id': _typeId,
          'name': name,
          if (room.isNotEmpty) 'room_number': room,
          'capacity': ?capacity,
          if (description.isNotEmpty) 'description': description,
        });
        AppSnackbar.success('Space created', '$name added.');
      } else {
        // Partial update: only fields that actually changed from `existing`.
        final existing = widget.existing!;
        final body = <String, dynamic>{
          if (_typeId != existing.spaceTypeId) 'space_type_id': _typeId,
          if (name != existing.name) 'name': name,
          if (room != (existing.roomNumber ?? '')) 'room_number': room,
          if (capacity != existing.capacity) 'capacity': capacity,
          if (description != (existing.description ?? '')) 'description': description,
        };
        if (body.isNotEmpty) await _repo.updateSpace(existing.id, body);
        AppSnackbar.success('Space updated', '$name saved.');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AppSnackbar.error('Save failed', e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.existing == null ? 'Add Space' : 'Edit Space',
      subtitle: 'Floor ${widget.floorId}',
      children: [
        DropdownButtonFormField<int>(
          initialValue: _typeId,
          decoration: const InputDecoration(labelText: 'Space Type'),
          items: [
            for (final t in widget.spaceTypes) DropdownMenuItem(value: t.id, child: Text(t.name)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _typeId = v);
          },
        ),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Space Name *', hintText: 'e.g. Library, Room 204')),
        const SizedBox(height: 12),
        TextField(controller: _room, decoration: const InputDecoration(labelText: 'Room Number (optional)', hintText: 'e.g. 204')),
        const SizedBox(height: 12),
        TextField(controller: _cap, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity (optional)')),
        const SizedBox(height: 12),
        TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : (widget.existing == null ? 'Create Space' : 'Save Changes')),
          ),
        ),
      ],
    );
  }
}
