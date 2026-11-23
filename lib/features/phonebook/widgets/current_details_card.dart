import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../core/models/alumni/alumni_current_details.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/alumni/alumni_current_details_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../models/phonebook_models.dart';
import '../services/student_id_resolver.dart';

/// "Current address & work" on an alumnus's profile: city, company, role and
/// (optionally) the full address, noted by admins after talking to them.
/// Saved on the server against the numeric `students.id`: [knownStudentId]
/// when the opener has it (Daily Alumni Connect), else found by exact Aadhar,
/// else confirmed by the admin from a list ([StudentIdResolver]).
class CurrentDetailsCard extends StatefulWidget {
  final PhonebookStudent student;
  final int? knownStudentId;
  final AlumniCurrentDetailsRepository? repository;

  const CurrentDetailsCard({super.key, required this.student, this.knownStudentId, this.repository});

  @override
  State<CurrentDetailsCard> createState() => _CurrentDetailsCardState();
}

class _CurrentDetailsCardState extends State<CurrentDetailsCard> {
  static const _accent = Color(0xFF0D9488);

  late final AlumniCurrentDetailsRepository _repo = widget.repository ?? AlumniCurrentDetailsRepository();

  int? _studentId;
  AlumniCurrentDetails _details = AlumniCurrentDetails.empty;
  bool _loading = true;
  bool _needsLink = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final known = widget.knownStudentId;
    _studentId ??= (known != null && known > 0) ? known : await StudentIdResolver.byAadhar(widget.student);
    if (!mounted) return;
    if (_studentId == null) {
      setState(() {
        _loading = false;
        _needsLink = true;
      });
      return;
    }
    try {
      final details = await _repo.fetch(_studentId!);
      if (!mounted) return;
      setState(() {
        _details = details;
        _needsLink = false;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load the current details.";
        _loading = false;
      });
    }
  }

  /// No Aadhar match: the admin confirms which student this is.
  Future<void> _link() async {
    final id = await StudentIdResolver.confirmFromList(context, widget.student.name);
    if (id == null) {
      AppSnackbar.info('Not Linked', 'No student was chosen, so nothing can be saved yet.');
      return;
    }
    _studentId = id;
    await _load();
  }

  Future<void> _edit() async {
    final id = _studentId;
    if (id == null) return;
    final updated = await _CurrentDetailsSheet.show(context, before: _details, onSave: (changes) => _repo.save(id, changes));
    if (updated != null && mounted) {
      setState(() => _details = updated);
      AppSnackbar.success('Saved', 'Current address & work updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhonebookTheme.border),
        boxShadow: [BoxShadow(color: PhonebookTheme.ink.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: const Icon(Icons.work_outline_rounded, size: 13, color: _accent),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CURRENT ADDRESS & WORK',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: PhonebookTheme.ink),
                ),
              ),
              if (!_loading && !_needsLink && _error == null)
                TextButton.icon(
                  onPressed: _edit,
                  icon: Icon(_details.isEmpty ? Icons.add_rounded : Icons.edit_rounded, size: 16),
                  label: Text(_details.isEmpty ? 'Add' : 'Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_needsLink)
            _Message(
              text: 'Confirm which student this is to add their city, company and role.',
              action: 'Link student',
              onTap: _link,
            )
          else if (_error != null)
            _Message(text: _error!, action: 'Retry', onTap: _load, isError: true)
          else if (_details.isEmpty)
            const Text(
              'Nothing noted yet. Add the city, company and role after talking to them.',
              style: TextStyle(fontSize: 12.5, color: PhonebookTheme.muted, height: 1.35),
            )
          else ...[
            _Row(icon: Icons.location_city_rounded, label: 'City', value: _details.city),
            _Row(icon: Icons.business_rounded, label: 'Company', value: _details.company),
            _Row(icon: Icons.badge_outlined, label: 'Role', value: _details.role),
            _Row(icon: Icons.home_outlined, label: 'Address', value: _details.address),
            if (_details.updatedAt != null || _details.updatedBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    'Updated',
                    if (_details.updatedAt != null) DateFormat('d MMM yyyy').format(_details.updatedAt!),
                    if (_details.updatedBy != null) 'by ${_details.updatedBy}',
                  ].join(' '),
                  style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: PhonebookTheme.slate),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: PhonebookTheme.muted)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: PhonebookTheme.ink)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;
  final bool isError;

  const _Message({required this.text, required this.action, required this.onTap, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: isError ? PhonebookTheme.red : PhonebookTheme.muted, height: 1.35),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0D9488),
            side: const BorderSide(color: Color(0xFF99F6E4)),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// Edit sheet: city, company, role and full address. Saves only what changed.
class _CurrentDetailsSheet extends StatefulWidget {
  final AlumniCurrentDetails before;
  final Future<AlumniCurrentDetails> Function(Map<String, String> changes) onSave;

  const _CurrentDetailsSheet({required this.before, required this.onSave});

  static Future<AlumniCurrentDetails?> show(
    BuildContext context, {
    required AlumniCurrentDetails before,
    required Future<AlumniCurrentDetails> Function(Map<String, String> changes) onSave,
  }) {
    return showModalBottomSheet<AlumniCurrentDetails>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CurrentDetailsSheet(before: before, onSave: onSave),
    );
  }

  @override
  State<_CurrentDetailsSheet> createState() => _CurrentDetailsSheetState();
}

class _CurrentDetailsSheetState extends State<_CurrentDetailsSheet> {
  late final _city = TextEditingController(text: widget.before.city ?? '');
  late final _company = TextEditingController(text: widget.before.company ?? '');
  late final _role = TextEditingController(text: widget.before.role ?? '');
  late final _address = TextEditingController(text: widget.before.address ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _city.dispose();
    _company.dispose();
    _role.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final after = AlumniCurrentDetails(city: _v(_city), company: _v(_company), role: _v(_role), address: _v(_address));
    final changes = AlumniCurrentDetails.changes(widget.before, after);
    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(changes);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      AppSnackbar.error('Could Not Save', e.message);
    } catch (_) {
      AppSnackbar.error('Could Not Save', 'Something went wrong, try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: PhonebookTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Current address & work',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'What you learnt from talking to them. Leave a field empty if you don\'t know it.',
              style: TextStyle(fontSize: 12.5, color: PhonebookTheme.muted),
            ),
            const SizedBox(height: 16),
            _field(_city, 'City', 'e.g. Ahmedabad', Icons.location_city_rounded, 100),
            _field(_company, 'Company', 'e.g. Infosys', Icons.business_rounded, 100),
            _field(_role, 'Role', 'e.g. Software Engineer', Icons.badge_outlined, 100),
            _field(_address, 'Full address (optional)', 'House, area, landmark', Icons.home_outlined, 500, lines: 3),
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon, int max, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLength: max,
        minLines: lines,
        maxLines: lines,
        textCapitalization: TextCapitalization.words,
        decoration: phonebookInputDecoration(
          label: label,
          hint: hint,
          prefixIcon: Icon(icon, size: 20),
        ).copyWith(counterText: ''),
      ),
    );
  }
}
