import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/repository/space_amenities/space_amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import '../utils/space_amenity_ui.dart';

class MaintenanceUpdateSheet extends StatefulWidget {
  final int? assetId;
  final int? complaintId;
  final String assetName;
  final String currentCondition;
  final bool canReplaceAsset;

  const MaintenanceUpdateSheet({
    super.key,
    this.assetId,
    this.complaintId,
    required this.assetName,
    this.currentCondition = 'good',
    this.canReplaceAsset = false,
  });

  @override
  State<MaintenanceUpdateSheet> createState() => _MaintenanceUpdateSheetState();
}

class _MaintenanceUpdateSheetState extends State<MaintenanceUpdateSheet> {
  final _repo = Get.find<SpaceAmenitiesRepository>();
  String _action = 'inspect';
  late String _condition = widget.currentCondition;
  final _rootCauseCtrl = TextEditingController();
  final _workCtrl = TextEditingController();
  final _matCostCtrl = TextEditingController(text: '0');
  final _labCostCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  File? _beforePhoto;
  File? _afterPhoto;
  bool _saving = false;

  @override
  void dispose() {
    _rootCauseCtrl.dispose();
    _workCtrl.dispose();
    _matCostCtrl.dispose();
    _labCostCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _totalCost =>
      (double.tryParse(_matCostCtrl.text.trim()) ?? 0) +
      (double.tryParse(_labCostCtrl.text.trim()) ?? 0);

  (String assetStatus, String complaintStatus) get _previewStatuses {
    switch (_action) {
      case 'inspect':
        return ('faulty', 'IN_PROGRESS');
      case 'start_repair':
        return ('under_repair', 'IN_PROGRESS');
      case 'complete_repair':
        return ('working', 'RESOLVED');
      case 'service':
        return ('working', 'RESOLVED');
      case 'request_replacement':
        return ('awaiting_replacement', 'IN_PROGRESS');
      case 'replace_asset':
        return ('replaced', 'RESOLVED');
      default:
        return ('working', 'IN_PROGRESS');
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      String? beforeFile;
      String? afterFile;
      if (_beforePhoto != null) beforeFile = await _repo.uploadPhoto(_beforePhoto!);
      if (_afterPhoto != null) afterFile = await _repo.uploadPhoto(_afterPhoto!);

      await _repo.submitMaintenanceUpdate({
        if (widget.assetId != null) 'asset_id': widget.assetId,
        if (widget.complaintId != null) 'complaint_id': widget.complaintId,
        'action': _action,
        if (_rootCauseCtrl.text.trim().isNotEmpty) 'root_cause': _rootCauseCtrl.text.trim(),
        if (_workCtrl.text.trim().isNotEmpty) 'work_performed': _workCtrl.text.trim(),
        'material_cost': double.tryParse(_matCostCtrl.text.trim()) ?? 0,
        'labor_cost': double.tryParse(_labCostCtrl.text.trim()) ?? 0,
        'updated_condition': _condition,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'before_photo_file': ?beforeFile,
        'after_photo_file': ?afterFile,
      });
      AppSnackbar.success('Maintenance updated', 'Action saved and statuses updated.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AppSnackbar.error('Update failed', e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('inspect', 'Inspect'),
      ('start_repair', 'Start Repair'),
      ('complete_repair', 'Complete Repair'),
      ('service', 'Service'),
      ('request_replacement', 'Request Replacement'),
      if (widget.canReplaceAsset) ('replace_asset', 'Replace Asset'),
    ];
    final preview = _previewStatuses;
    final showWorkFields = _action != 'inspect';

    return SheetScaffold(
      title: 'Update Maintenance',
      subtitle: widget.assetName,
      children: [
        const Text('Select Action', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in actions)
              PhonebookTintChip(
                label: a.$2,
                selected: _action == a.$1,
                onTap: () => setState(() => _action = a.$1),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _rootCauseCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Root Cause'),
        ),
        if (showWorkFields) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _workCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Work Performed'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _matCostCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Material Cost (₹)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _labCostCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Labor Cost (₹)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PhonebookCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Maintenance Cost', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('₹${_totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: PhonebookTheme.blue)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _condition,
          decoration: const InputDecoration(labelText: 'Updated Asset Condition'),
          items: const [
            DropdownMenuItem(value: 'new', child: Text('New')),
            DropdownMenuItem(value: 'good', child: Text('Good')),
            DropdownMenuItem(value: 'fair', child: Text('Fair')),
            DropdownMenuItem(value: 'poor', child: Text('Poor')),
            DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
          ],
          onChanged: (v) { if (v != null) setState(() => _condition = v); },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                  if (f != null) setState(() => _beforePhoto = File(f.path));
                },
                icon: const Icon(Icons.photo_outlined, size: 16),
                label: Text(_beforePhoto == null ? 'Before Photo' : 'Before ✓'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
                  if (f != null) setState(() => _afterPhoto = File(f.path));
                },
                icon: const Icon(Icons.photo_camera_outlined, size: 16),
                label: Text(_afterPhoto == null ? 'After Photo' : 'After ✓'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Additional Notes'),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PhonebookTheme.blueSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PhonebookTheme.blue.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resulting Status Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
              const SizedBox(height: 4),
              Text(
                'Asset: ${SpaceAmenityUi.statusLabel(preview.$1)}${widget.complaintId != null ? ' · Complaint: ${preview.$2}' : ''}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Submitting…' : 'Submit Maintenance Update'),
          ),
        ),
      ],
    );
  }
}
