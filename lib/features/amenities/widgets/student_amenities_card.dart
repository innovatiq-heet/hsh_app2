import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/enums/user_role.dart';
import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/utils/date_formatting.dart';
import '../../phonebook/models/phonebook_models.dart';
import '../../phonebook/services/student_id_resolver.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../utils/amenity_format.dart';
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

  Widget _group(
    String title,
    List<AmenityAssignment> items, {
    required String status,
    required Color statusColor,
    bool returnable = false,
    int? limit,
  }) {
    final shown = limit == null || items.length <= limit ? items : items.take(limit).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: PhonebookTheme.ink),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${items.length}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: PhonebookTheme.blue),
              ),
            ),
          ],
        ),
      ),
      for (final a in shown)
        _StudentAmenityTile(
          assignment: a,
          status: status,
          statusColor: statusColor,
          onTap: () => _open(a),
          onReturn: returnable && a.isOpen ? () => _return(a) : null,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhonebookTheme.border),
        boxShadow: [
          BoxShadow(
            color: PhonebookTheme.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: PhonebookTheme.blueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.inventory_2_outlined, size: 16, color: PhonebookTheme.blue),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AMENITIES & ROOM ASSETS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: PhonebookTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2),
                ),
              ),
            )
          else if (_needsLink)
            _Message(text: 'Confirm which student this is to see their keys and items.', action: 'Link student', onTap: _link)
          else if (_error != null)
            _Message(text: _error!, action: 'Retry', onTap: _load, isError: true)
          else if (d.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No amenities or keys assigned to this student.',
                style: TextStyle(fontSize: 13, color: PhonebookTheme.muted, fontWeight: FontWeight.w500),
              ),
            )
          else ...[
            if (d.current.isNotEmpty)
              _group(
                'With this student now',
                d.current,
                status: 'Assigned',
                statusColor: PhonebookTheme.green,
                returnable: true,
              ),
            if (d.lostOrDamaged.isNotEmpty)
              _group(
                'Lost or damaged',
                d.lostOrDamaged,
                status: 'Needs attention',
                statusColor: PhonebookTheme.red,
              ),
            if (d.returned.isNotEmpty)
              _group(
                'Previously held',
                d.returned,
                status: 'Returned',
                statusColor: PhonebookTheme.muted,
                limit: _showAllReturned ? null : _returnedShown,
              ),
          ],
        ],
      ),
    );
  }
}

class _StudentAmenityTile extends StatelessWidget {
  final AmenityAssignment assignment;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback? onReturn;

  const _StudentAmenityTile({
    required this.assignment,
    required this.status,
    required this.statusColor,
    required this.onTap,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final asset = a.asset;
    final itemName = [asset?.typeName, a.typeName]
        .whereType<String>()
        .map((v) => v.trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => 'Amenity item');
    final code = (asset?.assetCode ?? '').trim();
    final room = (a.roomNumber ?? '').trim();
    final quantity = a.isBulk ? (a.isOpen ? a.outstanding : a.quantity) : 1;
    final assigned = a.assignedAt == null ? null : DateFormatting.dateOnly(a.assignedAt!);
    final closed = a.closedAt == null ? null : DateFormatting.dateOnly(a.closedAt!);
    final condition = a.conditionAtAssignment == null ? null : AmenityFormat.condition(a.conditionAtAssignment!);
    final effectiveStatus = a.closeReason == 'lost'
        ? 'Lost'
        : a.closeReason == 'damaged'
            ? 'Damaged'
            : status;

    final details = <String>[
      if (code.isNotEmpty) code,
      if (a.isBulk) '$quantity ${a.unit}',
      if (room.isNotEmpty) 'Room $room',
    ];
    final dates = assigned == null
        ? (closed == null ? null : 'Closed on $closed')
        : closed == null
            ? 'Assigned on $assigned'
            : 'Held from $assigned to $closed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFFAFCFE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: PhonebookTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        a.isBulk ? Icons.inventory_2_outlined : Icons.qr_code_2_rounded,
                        color: statusColor,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: PhonebookTheme.ink,
                            ),
                          ),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              details.join('  \u2022  '),
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: PhonebookTheme.slate,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AmenityChip(effectiveStatus, color: effectiveStatus == status ? statusColor : PhonebookTheme.red),
                  ],
                ),
                if (dates != null || condition != null) ...[
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      if (dates != null) _TileFact(icon: Icons.calendar_today_outlined, text: dates),
                      if (condition != null) _TileFact(icon: Icons.health_and_safety_outlined, text: 'Issued: $condition'),
                    ],
                  ),
                ],
                if (onReturn != null) ...[
                  const Divider(height: 20, color: PhonebookTheme.border),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onReturn,
                      icon: const Icon(Icons.keyboard_return_rounded, size: 18),
                      label: const Text('Return item'),
                      style: TextButton.styleFrom(
                        foregroundColor: PhonebookTheme.green,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileFact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TileFact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PhonebookTheme.muted),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted, fontWeight: FontWeight.w500)),
        ],
      );
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
