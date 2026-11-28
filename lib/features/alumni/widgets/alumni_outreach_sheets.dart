import 'package:flutter/material.dart';
import '../controllers/alumni_daily_outreach_controller.dart';

class _SheetColors {
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF8FAFC);
  static const accent = Color(0xFF0284C7);
  static const positive = Color(0xFF16A34A);
  static const positiveSoft = Color(0xFFDCFCE7);
  static const neutral = Color(0xFFD97706);
  static const neutralSoft = Color(0xFFFEF3C7);
  static const negative = Color(0xFFE11D48);
  static const negativeSoft = Color(0xFFFFE4E6);
}

/// Bottom sheet for marking Reachable (with Positive / Neutral / Negative
/// response) or Not Reachable (offering the admin-only Edit Profile action
/// without opening it automatically).
Future<void> showOutreachStatusSheet(
  BuildContext context, {
  required AlumniDailyOutreachController controller,
  required int studentId,
  required String name,
  required String currentReachability,
  String? currentResponse,
  String? currentNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _OutreachStatusSheetBody(
      controller: controller,
      studentId: studentId,
      name: name,
      initialReachability: currentReachability,
      initialResponse: currentResponse,
      initialNote: currentNote,
      hostContext: context,
    ),
  );
}

class _OutreachStatusSheetBody extends StatefulWidget {
  final AlumniDailyOutreachController controller;
  final int studentId;
  final String name;
  final String initialReachability;
  final String? initialResponse;
  final String? initialNote;
  final BuildContext hostContext;

  const _OutreachStatusSheetBody({
    required this.controller,
    required this.studentId,
    required this.name,
    required this.initialReachability,
    this.initialResponse,
    this.initialNote,
    required this.hostContext,
  });

  @override
  State<_OutreachStatusSheetBody> createState() =>
      _OutreachStatusSheetBodyState();
}

class _OutreachStatusSheetBodyState extends State<_OutreachStatusSheetBody> {
  late String _reachability;
  String? _response;
  late final TextEditingController _noteCtrl;
  bool _saving = false;
  bool _notReachableSaved = false;

  @override
  void initState() {
    super.initState();
    _reachability = widget.initialReachability == 'reachable' ||
            widget.initialReachability == 'not_reachable'
        ? widget.initialReachability
        : '';
    _response = widget.initialResponse;
    _notReachableSaved = _reachability == 'not_reachable';
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectNotReachable() async {
    if (_saving) return;
    setState(() {
      _reachability = 'not_reachable';
      _response = null;
      _saving = true;
    });
    final ok = await widget.controller.updateStatusAndResponse(
      studentId: widget.studentId,
      name: widget.name,
      reachability: 'not_reachable',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _notReachableSaved = true;
    });
    if (ok && !widget.controller.canEditProfile) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveReachable(String response) async {
    if (_saving) return;
    setState(() {
      _reachability = 'reachable';
      _response = response;
      _saving = true;
    });
    final ok = await widget.controller.updateStatusAndResponse(
      studentId: widget.studentId,
      name: widget.name,
      reachability: 'reachable',
      outreachResponse: response,
      outreachResponseNote: _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.controller.canEditProfile;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _SheetColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Update call / WhatsApp status & response',
                style: TextStyle(fontSize: 12.5, color: _SheetColors.muted),
              ),
              const SizedBox(height: 16),

              // Two primary choices only: Reachable vs Not Reachable
              Row(
                children: [
                  Expanded(
                    child: _StatusChoiceTile(
                      label: 'Reachable',
                      icon: Icons.check_circle_outline_rounded,
                      selected: _reachability == 'reachable',
                      color: _SheetColors.positive,
                      softColor: _SheetColors.positiveSoft,
                      onTap: _saving
                          ? null
                          : () => setState(() {
                                _reachability = 'reachable';
                                _notReachableSaved = false;
                              }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatusChoiceTile(
                      label: 'Not Reachable',
                      icon: Icons.phone_disabled_rounded,
                      selected: _reachability == 'not_reachable',
                      color: _SheetColors.negative,
                      softColor: _SheetColors.negativeSoft,
                      onTap: _saving ? null : _selectNotReachable,
                    ),
                  ),
                ],
              ),

              if (_reachability == 'reachable') ...[
                const SizedBox(height: 16),
                const Text(
                  'How did they respond?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _SheetColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ResponseChip(
                        label: 'Positive',
                        icon: Icons.thumb_up_alt_rounded,
                        color: _SheetColors.positive,
                        softColor: _SheetColors.positiveSoft,
                        selected: _response == 'positive',
                        onTap: _saving ? null : () => _saveReachable('positive'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResponseChip(
                        label: 'Neutral',
                        icon: Icons.sentiment_neutral_rounded,
                        color: _SheetColors.neutral,
                        softColor: _SheetColors.neutralSoft,
                        selected: _response == 'neutral',
                        onTap: _saving ? null : () => _saveReachable('neutral'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResponseChip(
                        label: 'Negative',
                        icon: Icons.thumb_down_alt_rounded,
                        color: _SheetColors.negative,
                        softColor: _SheetColors.negativeSoft,
                        selected: _response == 'negative',
                        onTap: _saving ? null : () => _saveReachable('negative'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLength: 300,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Optional short note before picking response...',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: _SheetColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _SheetColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _SheetColors.border),
                    ),
                  ),
                ),
              ],

              if (_reachability == 'not_reachable' && _notReachableSaved) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _SheetColors.negativeSoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _SheetColors.negative.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: _SheetColors.negative,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Marked as Not Reachable',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _SheetColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (canEdit) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'You can update their WhatsApp number or complete profile whenever needed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _SheetColors.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Done'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _SheetColors.accent,
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  showAdminFullProfileEditorSheet(
                                    widget.hostContext,
                                    controller: widget.controller,
                                    studentId: widget.studentId,
                                    fallbackName: widget.name,
                                  );
                                },
                                icon: const Icon(Icons.person_outline_rounded, size: 18),
                                label: const Text('Edit Profile'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (_saving) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final Color softColor;
  final VoidCallback? onTap;

  const _StatusChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.softColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? softColor : _SheetColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : _SheetColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : _SheetColors.muted, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? color : _SheetColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
  final bool selected;
  final VoidCallback? onTap;

  const _ResponseChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.softColor,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? softColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : _SheetColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? color : _SheetColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin-only bottom sheet to edit the complete alumnus profile, phone/WhatsApp
/// number, career details, and academic details. Leaders never see or access this.
Future<void> showAdminFullProfileEditorSheet(
  BuildContext context, {
  required AlumniDailyOutreachController controller,
  required int studentId,
  required String fallbackName,
}) {
  if (!controller.canEditProfile) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _AdminFullProfileSheet(
      controller: controller,
      studentId: studentId,
      fallbackName: fallbackName,
    ),
  );
}

class _AdminFullProfileSheet extends StatefulWidget {
  final AlumniDailyOutreachController controller;
  final int studentId;
  final String fallbackName;

  const _AdminFullProfileSheet({
    required this.controller,
    required this.studentId,
    required this.fallbackName,
  });

  @override
  State<_AdminFullProfileSheet> createState() => _AdminFullProfileSheetState();
}

class _AdminFullProfileSheetState extends State<_AdminFullProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _gradYearCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.controller.loadFullProfile(widget.studentId);
      if (!mounted) return;
      _nameCtrl.text = (p['name'] ?? widget.fallbackName).toString();
      _phoneCtrl.text = (p['phone_number'] ?? '').toString();
      _waCtrl.text = (p['whatsapp_number'] ?? '').toString();
      _emailCtrl.text = (p['email'] ?? '').toString();
      _roomCtrl.text = (p['past_room'] ?? '').toString();
      _groupCtrl.text = (p['group_name'] ?? '').toString();
      _companyCtrl.text = (p['current_company'] ?? '').toString();
      _designationCtrl.text = (p['current_designation'] ?? '').toString();
      _cityCtrl.text = (p['current_city'] ?? '').toString();
      _addressCtrl.text = (p['current_address'] ?? '').toString();
      _degreeCtrl.text = (p['degree'] ?? '').toString();
      _fieldCtrl.text = (p['field_of_study'] ?? '').toString();
      _gradYearCtrl.text = p['graduation_year']?.toString() ?? '';
      _bioCtrl.text = (p['bio'] ?? '').toString();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _emailCtrl.dispose();
    _roomCtrl.dispose();
    _groupCtrl.dispose();
    _companyCtrl.dispose();
    _designationCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _degreeCtrl.dispose();
    _fieldCtrl.dispose();
    _gradYearCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final ok = await widget.controller.saveFullProfile(widget.studentId, {
      'name': _nameCtrl.text.trim(),
      'phone_number': _phoneCtrl.text.trim(),
      'whatsapp_number': _waCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'past_room': _roomCtrl.text.trim(),
      'group_name': _groupCtrl.text.trim(),
      'current_company': _companyCtrl.text.trim(),
      'current_designation': _designationCtrl.text.trim(),
      'current_city': _cityCtrl.text.trim(),
      'current_address': _addressCtrl.text.trim(),
      'degree': _degreeCtrl.text.trim(),
      'field_of_study': _fieldCtrl.text.trim(),
      'graduation_year': _gradYearCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: _SheetColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Complete Profile',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _SheetColors.ink,
                        ),
                      ),
                      Text(
                        widget.fallbackName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: _SheetColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_loadError!, textAlign: TextAlign.center),
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: ListView(
                          controller: scrollCtrl,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            16,
                            20,
                            MediaQuery.viewInsetsOf(context).bottom + 24,
                          ),
                          children: [
                            _sectionLabel('Contact & Hostel'),
                            _field(_nameCtrl, 'Full Name', required: true),
                            _field(_phoneCtrl, 'Primary Mobile', keyboard: TextInputType.phone),
                            _field(_waCtrl, 'WhatsApp Number', keyboard: TextInputType.phone),
                            _field(_emailCtrl, 'Email', keyboard: TextInputType.emailAddress),
                            Row(
                              children: [
                                Expanded(child: _field(_roomCtrl, 'Past Room')),
                                const SizedBox(width: 10),
                                Expanded(child: _field(_groupCtrl, 'Group')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _sectionLabel('Work & Location'),
                            _field(_companyCtrl, 'Current Company'),
                            _field(_designationCtrl, 'Designation / Role'),
                            _field(_cityCtrl, 'Current City'),
                            _field(_addressCtrl, 'Current Address', maxLines: 2),
                            const SizedBox(height: 8),
                            _sectionLabel('Education & Notes'),
                            Row(
                              children: [
                                Expanded(child: _field(_degreeCtrl, 'Degree')),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    _gradYearCtrl,
                                    'Grad Year',
                                    keyboard: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            _field(_fieldCtrl, 'Field of Study'),
                            _field(_bioCtrl, 'Bio / Notes', maxLines: 3),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _SheetColors.accent,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_rounded, size: 18),
                              label: Text(_saving ? 'Saving...' : 'Save Complete Profile'),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: _SheetColors.muted,
          ),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          maxLines: maxLines,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
              : null,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: _SheetColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}
