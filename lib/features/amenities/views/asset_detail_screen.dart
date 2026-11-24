import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/amenities/amenity_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/repository/amenities/amenities_repository.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatting.dart';
import '../../shared/widgets/phonebook_style_widgets.dart';
import '../utils/amenity_format.dart';
import '../widgets/amenity_sheets.dart';

/// One individually tracked asset: Overview, Lifecycle, Assignments and
/// Activity, with the actions its state allows. Opened from lists, a room,
/// a student's amenities or a scanned QR code.
class AssetDetailScreen extends StatefulWidget {
  final int assetId;
  final AmenitiesRepository? repository;

  const AssetDetailScreen({super.key, required this.assetId, this.repository});

  static Future<void> open(BuildContext context, int assetId) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AssetDetailScreen(assetId: assetId)));

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late final AmenitiesRepository _repo = widget.repository ?? AmenitiesRepository();
  AmenityAsset? _asset;
  String? _error;
  bool _loading = true;
  List<AmenityLocation>? _locations;
  int _version = 0; // bump to reload the tabs

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
    try {
      final a = await _repo.asset(widget.assetId);
      if (!mounted) return;
      setState(() {
        _asset = a;
        _loading = false;
        _version++;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    } catch (_) {
      if (mounted) setState(() => (_error = "Couldn't load this item.", _loading = false));
    }
  }

  Future<List<AmenityLocation>> _locs() async => _locations ??= await _repo.locations().catchError((_) => <AmenityLocation>[]);

  Future<void> _assign({bool transfer = false}) async {
    final a = _asset!;
    final type = await _repo.type(a.typeId).then<AmenityType?>((t) => t).catchError((_) => null);
    final locations = await _locs();
    if (!mounted) return;
    final ok = await showAssignSheet(
      context,
      repo: _repo,
      locations: locations,
      asset: a,
      transfer: transfer,
      studentsAllowed: type?.assignableToStudents ?? true,
    );
    if (ok) await _load();
  }

  Future<void> _return() async {
    final cur = _asset?.currentAssignment;
    if (cur == null) return;
    if (await showReturnSheet(context, repo: _repo, assignment: cur)) await _load();
  }

  Future<void> _status() async {
    if (await showStatusSheet(context, repo: _repo, asset: _asset!)) await _load();
  }

  void _showQr() {
    final a = _asset!;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 220, height: 220, child: QrImageView(data: a.qrPayload ?? a.assetCode, backgroundColor: Colors.white)),
            const SizedBox(height: 10),
            SelectableText(a.assetCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
            Text('${a.typeName}${a.label == null ? '' : ' · ${a.label}'}', style: const TextStyle(color: PhonebookTheme.muted)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _asset;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: PhonebookTheme.bg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF032B4F),
          foregroundColor: Colors.white,
          title: Text(a?.assetCode ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (a != null) IconButton(tooltip: 'Show QR', onPressed: _showQr, icon: const Icon(Icons.qr_code_2_rounded)),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: PhonebookTheme.amberBright,
            tabs: [Tab(text: 'Overview'), Tab(text: 'Lifecycle'), Tab(text: 'Assignments'), Tab(text: 'Activity')],
          ),
        ),
        body: _loading && a == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : (_error != null && a == null)
                ? _ErrorBlock(message: _error!, onRetry: _load)
                : TabBarView(
                    children: [
                      RefreshIndicator(onRefresh: _load, child: _overview(a!)),
                      AmenityEventsList(key: ValueKey('ev$_version'), load: (o) => _repo.assetEvents(a.id, offset: o)),
                      _AssignmentsTab(key: ValueKey('as$_version'), repo: _repo, assetId: a.id, onChanged: _load),
                      AmenityEventsList(key: ValueKey('ac$_version'), load: (o) => _repo.activity(assetId: a.id, offset: o), activity: true),
                    ],
                  ),
      ),
    );
  }

  Widget _overview(AmenityAsset a) {
    final cur = a.currentAssignment;
    final placement = switch (a.placement) {
      AssetPlacement.installed => 'Installed · ${cur?.location?.path ?? '-'}',
      AssetPlacement.withStudent => 'With ${cur?.student?.name ?? 'a student'}${cur?.roomNumber == null ? '' : ' · Room ${cur!.roomNumber}'}',
      AssetPlacement.inStore => 'In store${a.homeLocation == null ? '' : ' · ${a.homeLocation!.path}'}',
    };
    final usable = !a.isRetired && a.status != AssetStatus.lost;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        PhonebookCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: a.assetCode));
                  AppSnackbar.success('Copied', a.assetCode);
                },
                child: Text(a.assetCode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
              ),
              const SizedBox(height: 2),
              Text('${a.typeName}${a.categoryName == null ? '' : ' · ${a.categoryName}'}${a.label == null ? '' : ' · ${a.label}'}',
                  style: const TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                AmenityChip(AmenityFormat.status(a.status), color: AmenityFormat.statusColor(a.status)),
                if (a.condition != null) AmenityChip(AmenityFormat.condition(a.condition!), color: PhonebookTheme.slate),
                if (a.warranty == 'expiring' || a.warranty == 'expired')
                  AmenityChip(AmenityFormat.warranty(a.warranty), color: a.warranty == 'expired' ? PhonebookTheme.red : PhonebookTheme.amber),
                if (a.maintenanceDue) const AmenityChip('Maintenance due', color: PhonebookTheme.amber),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.place_outlined, size: 17, color: PhonebookTheme.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(placement, style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink))),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (usable && cur == null) _ActionButton('Assign', Icons.person_add_alt_1_rounded, () => _assign()),
                if (usable && cur != null) _ActionButton('Move', Icons.swap_horiz_rounded, () => _assign(transfer: true)),
                if (cur != null) _ActionButton('Return', Icons.keyboard_return_rounded, _return),
                if (!a.isRetired) _ActionButton('Status', Icons.sync_alt_rounded, _status),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PhonebookCard(
          child: Column(children: [
            _Row('Serial number', a.serialNumber ?? '-'),
            _Row('Purchased', '${AmenityFormat.date(a.purchaseDate)}${a.purchaseCost == null ? '' : ' · ${AmenityFormat.money(a.purchaseCost)}'}'),
            _Row('Vendor', a.vendor ?? '-'),
            _Row('Installed', AmenityFormat.date(a.installationDate)),
            _Row('Age', AmenityFormat.age(a.ageMonths)),
            _Row('Warranty', a.warrantyExpiry == null ? 'None' : '${AmenityFormat.warranty(a.warranty)} · until ${AmenityFormat.date(a.warrantyExpiry)}'),
            _Row('Expected life', a.expectedLifeMonths == null ? '-' : '${a.expectedLifeMonths} months · replace by ${AmenityFormat.date(a.replacementDue)}'),
            _Row('Next maintenance', AmenityFormat.date(a.nextMaintenanceDue)),
            if (a.maintenanceCount > 0) _Row('Repairs', '${a.maintenanceCount} · ${AmenityFormat.money(a.maintenanceCostTotal)}'),
            if (a.notes != null) _Row('Notes', a.notes!),
            _Row('Added', '${a.createdAt == null ? '-' : DateFormatting.dateOnly(a.createdAt!)}${a.createdByName == null ? '' : ' by ${a.createdByName}'}'),
            if (a.updatedAt != null) _Row('Last change', '${DateFormatting.dateTime(a.updatedAt!)}${a.updatedByName == null ? '' : ' by ${a.updatedByName}'}'),
          ]),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: PhonebookTheme.blue,
          side: BorderSide(color: PhonebookTheme.blue.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: PhonebookTheme.ink, fontWeight: FontWeight.w600, fontSize: 13.5))),
        ]),
      );
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: PhonebookTheme.muted),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: PhonebookTheme.slate)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}

/// A paged list of events: an asset's lifecycle timeline, or the activity log.
class AmenityEventsList extends StatefulWidget {
  final Future<Paged<AmenityEvent>> Function(int offset) load;
  final bool activity;

  const AmenityEventsList({super.key, required this.load, this.activity = false});

  @override
  State<AmenityEventsList> createState() => _AmenityEventsListState();
}

class _AmenityEventsListState extends State<AmenityEventsList> {
  final _items = <AmenityEvent>[];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.load(_items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => (_error = e is ApiException ? e.message : "Couldn't load the history.", _loading = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_items.isEmpty && _error != null) return _ErrorBlock(message: _error!, onRetry: _more);
    if (_items.isEmpty) return const Center(child: Text('Nothing recorded yet.', style: TextStyle(color: PhonebookTheme.muted)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _items.length + (_items.length < _total ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Center(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _more, child: const Text('Load more')),
          );
        }
        final e = _items[i];
        final when = e.happenedOn != null ? AmenityFormat.date(e.happenedOn) : (e.at == null ? '' : DateFormatting.dateTime(e.at!));
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(AmenityFormat.eventIcon(e.event), size: 17, color: PhonebookTheme.blue),
              ),
              if (i < _items.length - 1) Expanded(child: Container(width: 2, color: PhonebookTheme.border)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${widget.activity && e.assetCode != null ? '${e.assetCode} · ' : ''}${AmenityFormat.event(e)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: PhonebookTheme.ink),
                  ),
                  if (e.note != null) Text(e.note!, style: const TextStyle(color: PhonebookTheme.slate, fontSize: 12.5)),
                  Text('$when${e.byName == null ? '' : ' · by ${e.byName}'}', style: const TextStyle(color: PhonebookTheme.muted, fontSize: 12)),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Current assignment first, then the previous ones (newest first).
class _AssignmentsTab extends StatefulWidget {
  final AmenitiesRepository repo;
  final int assetId;
  final VoidCallback onChanged;

  const _AssignmentsTab({super.key, required this.repo, required this.assetId, required this.onChanged});

  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> {
  late Future<List<AmenityAssignment>> _future = widget.repo.assetAssignments(widget.assetId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AmenityAssignment>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        if (snap.hasError) {
          return _ErrorBlock(
            message: snap.error is ApiException ? (snap.error as ApiException).message : "Couldn't load the assignments.",
            onRetry: () => setState(() => _future = widget.repo.assetAssignments(widget.assetId)),
          );
        }
        final list = snap.data ?? const <AmenityAssignment>[];
        if (list.isEmpty) return const Center(child: Text('Never assigned yet.', style: TextStyle(color: PhonebookTheme.muted)));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [for (final a in list) AssignmentTile(assignment: a)],
        );
      },
    );
  }
}

/// One assignment: who or where, dates, condition out and back.
class AssignmentTile extends StatelessWidget {
  final AmenityAssignment assignment;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showItem;

  const AssignmentTile({super.key, required this.assignment, this.onTap, this.trailing, this.showItem = false});

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final who = a.student != null
        ? '${a.student!.name}${a.roomNumber == null ? '' : ' · Room ${a.roomNumber}'}'
        : (a.location?.path ?? '-');
    final since = a.assignedAt == null ? '' : DateFormatting.dateOnly(a.assignedAt!);
    final until = a.closedAt == null ? 'now' : DateFormatting.dateOnly(a.closedAt!);
    final cond = [
      if (a.conditionAtAssignment != null) 'out ${AmenityFormat.condition(a.conditionAtAssignment!)}',
      if (a.conditionAtReturn != null) 'back ${AmenityFormat.condition(a.conditionAtReturn!)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PhonebookCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(a.student != null ? Icons.person_rounded : Icons.place_rounded, color: a.isOpen ? PhonebookTheme.green : PhonebookTheme.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showItem) Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, color: PhonebookTheme.ink)),
              Text(showItem ? who : (a.isBulk ? '$who · ${a.quantity} ${a.unit}' : who),
                  style: TextStyle(fontWeight: showItem ? FontWeight.w600 : FontWeight.w800, color: showItem ? PhonebookTheme.slate : PhonebookTheme.ink)),
              Text('$since – $until${a.closeReason == null ? '' : ' · ${a.closeReason}'}',
                  style: const TextStyle(fontSize: 12.5, color: PhonebookTheme.muted)),
              if (cond.isNotEmpty) Text(cond, style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted)),
            ]),
          ),
          if (a.isOpen) const AmenityChip('Current', color: PhonebookTheme.green),
          ?trailing,
        ]),
      ),
    );
  }
}
