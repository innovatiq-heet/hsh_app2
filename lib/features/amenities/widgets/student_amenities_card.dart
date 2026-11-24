import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/enums/user_role.dart';
import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../../phonebook/services/student_id_resolver.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../views/amenity_type_screen.dart';
import '../views/asset_detail_screen.dart';
import 'amenity_sheets.dart';

/// "Amenities" on a student's profile: what they have now, what they lost or
/// damaged, and what they returned. Loaded by the numeric `students.id`:
/// [knownStudentId] when the opener has it, else the exact Aadhar, else the
/// admin confirms the student from a list ([StudentIdResolver]). Never by
/// bank code or name alone. Admins and wardens only.
class StudentAmenitiesCard extends StatefulWidget {
  final PhonebookStudent student;
  final int? knownStudentId;
  final AmenitiesRepository? repository;

  const StudentAmenitiesCard({super.key, required this.student, this.knownStudentId, this.repository});

  /// Whether the signed-in user may see the card.
  static bool get visible =>
      Get.isRegistered<SessionStore>() && (Get.find<SessionStore>().currentSession?.role.canOperate ?? false);

  @override
  State<StudentAmenitiesCard> createState() => _StudentAmenitiesCardState();
}

class _StudentAmenitiesCardState extends State<StudentAmenitiesCard> {
  static const _accent = Color(0xFF7C3AED);
  static const _returnedShown = 5;

  late final AmenitiesRepository _repo = widget.repository ?? AmenitiesRepository();

  int? _studentId;
  StudentAmenities _data = const StudentAmenities();
  bool _loading = true;
  bool _needsLink = false;
  bool _showAllReturned = false;
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
      final data = await _repo.studentAmenities(_studentId!);
      if (!mounted) return;
      setState(() {
        _data = data;
        _needsLink = false;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    } catch (_) {
      if (mounted) setState(() => (_error = "Couldn't load this student's amenities.", _loading = false));
    }
  }

  Future<void> _link() async {
    final id = await StudentIdResolver.confirmFromList(context, widget.student.name);
    if (id == null) return;
    _studentId = id;
    await _load();
  }

  Future<void> _open(AmenityAssignment a) async {
    if (a.asset != null) {
      await AssetDetailScreen.open(context, a.asset!.id);
    } else if (a.typeId != null) {
      await AmenityTypeScreen.open(context, a.typeId!);
    } else {
      return;
    }
    if (mounted) await _load();
  }

  Future<void> _return(AmenityAssignment a) async {
    if (await showReturnSheet(context, repo: _repo, assignment: a)) await _load();
  }

  Widget _group(String title, List<AmenityAssignment> items, {bool returnable = false, int? limit}) {
    final shown = limit == null || items.length <= limit ? items : items.take(limit).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text('$title (${items.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PhonebookTheme.slate)),
      ),
      for (final a in shown)
        AssignmentTile(
          assignment: a,
          showItem: true,
          onTap: () => _open(a),
          trailing: returnable && a.isOpen
              ? IconButton(
                  tooltip: 'Take back',
                  onPressed: () => _return(a),
                  icon: const Icon(Icons.keyboard_return_rounded, color: PhonebookTheme.green),
                )
              : null,
        ),
      if (shown.length < items.length)
        TextButton(
          onPressed: () => setState(() => _showAllReturned = true),
          child: Text('Show all ${items.length}'),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhonebookTheme.border),
        boxShadow: [BoxShadow(color: PhonebookTheme.ink.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: const Icon(Icons.inventory_2_outlined, size: 13, color: _accent),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('AMENITIES',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: PhonebookTheme.ink)),
          ),
        ]),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_needsLink)
          _Message(text: 'Confirm which student this is to see their keys and items.', action: 'Link student', onTap: _link)
        else if (_error != null)
          _Message(text: _error!, action: 'Retry', onTap: _load, isError: true)
        else if (d.isEmpty)
          const Text('No items given to this student.', style: TextStyle(fontSize: 12.5, color: PhonebookTheme.muted))
        else ...[
          if (d.current.isNotEmpty) _group('Has now', d.current, returnable: true),
          if (d.lostOrDamaged.isNotEmpty) _group('Lost or damaged', d.lostOrDamaged),
          if (d.returned.isNotEmpty) _group('Returned', d.returned, limit: _showAllReturned ? null : _returnedShown),
        ],
      ]),
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
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: isError ? PhonebookTheme.red : PhonebookTheme.muted)),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ]);
}
