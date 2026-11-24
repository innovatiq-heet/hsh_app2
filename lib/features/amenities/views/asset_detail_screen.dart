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

/// Luminous circular background orb painter matching Phonebook & Screen Time headers.
class _AssetDetailOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.38, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), size.width * 0.62, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

  Future<List<AmenityLocation>> _locs() async =>
      _locations ??= await _repo.locations().catchError((_) => <AmenityLocation>[]);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PhonebookTheme.border),
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(data: a.qrPayload ?? a.assetCode, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              a.assetCode,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: PhonebookTheme.ink),
            ),
            const SizedBox(height: 2),
            Text(
              '${a.typeName}${a.label == null ? '' : ' · ${a.label}'}',
              style: const TextStyle(color: PhonebookTheme.muted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: a.qrPayload ?? a.assetCode));
              AppSnackbar.success('Copied', 'QR data copied to clipboard.');
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Data'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
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
        body: Column(
          children: [
            // Signature Deep Navy Header with Segmented Tabs
            _buildHeader(context, a),

            // Tab Views Content
            Expanded(
              child: _loading && a == null
                  ? const Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2.2))
                  : (_error != null && a == null)
                      ? _ErrorBlock(message: _error!, onRetry: _load)
                      : TabBarView(
                          children: [
                            RefreshIndicator(
                              onRefresh: _load,
                              color: PhonebookTheme.blue,
                              backgroundColor: Colors.white,
                              child: _overview(a!),
                            ),
                            AmenityEventsList(
                              key: ValueKey('ev$_version'),
                              load: (o) => _repo.assetEvents(a.id, offset: o),
                            ),
                            _AssignmentsTab(
                              key: ValueKey('as$_version'),
                              repo: _repo,
                              assetId: a.id,
                              onChanged: _load,
                            ),
                            AmenityEventsList(
                              key: ValueKey('ac$_version'),
                              load: (o) => _repo.activity(assetId: a.id, offset: o),
                              activity: true,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AmenityAsset? a) {
    return Container(
      decoration: const BoxDecoration(
        gradient: PhonebookTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3803192E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _AssetDetailOrbPainter())),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: Row(
                      children: [
                        PhonebookHeaderCircleButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a == null ? 'ASSET DETAILS' : 'ASSET ${a.assetCode}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: PhonebookTheme.amberBright,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a?.typeName ?? 'Asset Detail',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a == null ? '' : '${a.categoryName ?? ''}${a.label == null ? '' : ' · ${a.label}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (a != null) ...[
                          PhonebookHeaderCircleButton(
                            icon: Icons.qr_code_2_rounded,
                            tooltip: 'Show QR Code',
                            onTap: _showQr,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (a != null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            PhonebookHeaderPill(
                              icon: Icons.shield_outlined,
                              label: AmenityFormat.status(a.status),
                            ),
                            const SizedBox(width: 8),
                            PhonebookHeaderPill(
                              icon: Icons.place_outlined,
                              label: AmenityFormat.placement(a.placement),
                            ),
                            if (a.condition != null) ...[
                              const SizedBox(width: 8),
                              PhonebookHeaderPill(
                                icon: Icons.check_circle_outline_rounded,
                                label: AmenityFormat.condition(a.condition!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Segmented Tabs
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: PhonebookTheme.ink,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.82),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Overview', height: 36),
                        Tab(text: 'Lifecycle', height: 36),
                        Tab(text: 'Assignments', height: 36),
                        Tab(text: 'Activity', height: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview(AmenityAsset a) {
    final cur = a.currentAssignment;
    final placement = switch (a.placement) {
      AssetPlacement.installed => 'Installed · ${cur?.location?.path ?? '-'}',
      AssetPlacement.withStudent =>
        'With ${cur?.student?.name ?? 'a student'}${cur?.roomNumber == null ? '' : ' · Room ${cur!.roomNumber}'}',
      AssetPlacement.inStore => 'In store${a.homeLocation == null ? '' : ' · ${a.homeLocation!.path}'}',
    };
    final usable = !a.isRetired && a.status != AssetStatus.lost;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        PhonebookCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: a.assetCode));
                            AppSnackbar.success('Copied', a.assetCode);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                a.assetCode,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: PhonebookTheme.ink,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy_rounded, size: 16, color: PhonebookTheme.muted),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a.typeName}${a.categoryName == null ? '' : ' · ${a.categoryName}'}${a.label == null ? '' : ' · ${a.label}'}',
                          style: const TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                AmenityChip(AmenityFormat.status(a.status), color: AmenityFormat.statusColor(a.status)),
                if (a.condition != null) AmenityChip(AmenityFormat.condition(a.condition!), color: PhonebookTheme.slate),
                if (a.warranty == 'expiring' || a.warranty == 'expired')
                  AmenityChip(AmenityFormat.warranty(a.warranty),
                      color: a.warranty == 'expired' ? PhonebookTheme.red : PhonebookTheme.amber),
                if (a.maintenanceDue) const AmenityChip('Maintenance due', color: PhonebookTheme.amber),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PhonebookTheme.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PhonebookTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: PhonebookTheme.blueSoft, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.place_outlined, size: 18, color: PhonebookTheme.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        placement,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: PhonebookTheme.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (usable && cur == null)
                    _ActionButton('Assign to Student/Room', Icons.person_add_alt_1_rounded, () => _assign(), isPrimary: true),
                  if (usable && cur != null)
                    _ActionButton('Move Location', Icons.swap_horiz_rounded, () => _assign(transfer: true)),
                  if (cur != null)
                    _ActionButton('Return to Store', Icons.keyboard_return_rounded, _return),
                  if (!a.isRetired)
                    _ActionButton('Update Status', Icons.sync_alt_rounded, _status),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PhonebookSectionHeader(title: 'Asset Specifications & History'),
        PhonebookCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _Row('Serial number', a.serialNumber ?? '-'),
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row(
                'Purchased',
                '${AmenityFormat.date(a.purchaseDate)}${a.purchaseCost == null ? '' : ' · ${AmenityFormat.money(a.purchaseCost)}'}',
              ),
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row('Vendor', a.vendor ?? '-'),
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row('Installed', AmenityFormat.date(a.installationDate)),
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row('Age', AmenityFormat.age(a.ageMonths)),
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row('Warranty',
                  a.warrantyExpiry == null ? 'None' : '${AmenityFormat.warranty(a.warranty)} · until ${AmenityFormat.date(a.warrantyExpiry)}'),
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row('Expected life',
                  a.expectedLifeMonths == null ? '-' : '${a.expectedLifeMonths} months · replace by ${AmenityFormat.date(a.replacementDue)}'),
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row('Next maintenance', AmenityFormat.date(a.nextMaintenanceDue)),
              if (a.maintenanceCount > 0) ...[
                const Divider(height: 16, color: PhonebookTheme.border),
                _Row('Repairs', '${a.maintenanceCount} · ${AmenityFormat.money(a.maintenanceCostTotal)}'),
              ],
              if (a.notes != null) ...[
                const Divider(height: 16, color: PhonebookTheme.border),
                _Row('Notes', a.notes!),
              ],
              const Divider(height: 16, color: PhonebookTheme.border),
              _Row('Added',
                  '${a.createdAt == null ? '-' : DateFormatting.dateOnly(a.createdAt!)}${a.createdByName == null ? '' : ' by ${a.createdByName}'}'),
              if (a.updatedAt != null) ...[
                const Divider(height: 16, color: PhonebookTheme.border),
                _Row('Last change',
                    '${DateFormatting.dateTime(a.updatedAt!)}${a.updatedByName == null ? '' : ' by ${a.updatedByName}'}'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton(this.label, this.icon, this.onTap, {this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: PhonebookTheme.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: PhonebookTheme.blue,
        side: BorderSide(color: PhonebookTheme.blue.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: PhonebookTheme.ink, fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
        ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                child: const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: PhonebookTheme.slate, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
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
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2.2));
    }
    if (_items.isEmpty && _error != null) return _ErrorBlock(message: _error!, onRetry: _more);
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nothing recorded yet.', style: TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w500)),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _items.length + (_items.length < _total ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return Center(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2))
                : TextButton(onPressed: _more, child: const Text('Load more')),
          );
        }
        final e = _items[i];
        final when = e.happenedOn != null ? AmenityFormat.date(e.happenedOn) : (e.at == null ? '' : DateFormatting.dateTime(e.at!));
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: PhonebookTheme.blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(AmenityFormat.eventIcon(e.event), size: 18, color: PhonebookTheme.blue),
                  ),
                  if (i < _items.length - 1) Expanded(child: Container(width: 2, color: PhonebookTheme.border)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: PhonebookCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.activity && e.assetCode != null ? '${e.assetCode} · ' : ''}${AmenityFormat.event(e)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: PhonebookTheme.ink),
                        ),
                        if (e.note != null && e.note!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(e.note!, style: const TextStyle(color: PhonebookTheme.slate, fontSize: 12.5)),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: PhonebookTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              '$when${e.byName == null ? '' : ' · by ${e.byName}'}',
                              style: const TextStyle(color: PhonebookTheme.muted, fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: PhonebookTheme.blue, strokeWidth: 2.2));
        }
        if (snap.hasError) {
          return _ErrorBlock(
            message: snap.error is ApiException ? (snap.error as ApiException).message : "Couldn't load assignments.",
            onRetry: () => setState(() => _future = widget.repo.assetAssignments(widget.assetId)),
          );
        }
        final list = snap.data ?? const <AmenityAssignment>[];
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Never assigned yet.', style: TextStyle(color: PhonebookTheme.muted, fontWeight: FontWeight.w500)),
            ),
          );
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            const PhonebookSectionHeader(title: 'Assignment History'),
            for (final a in list) AssignmentTile(assignment: a),
          ],
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

    final iconBg = a.isOpen ? PhonebookTheme.greenSoft : const Color(0xFFF1F5F9);
    final iconColor = a.isOpen ? PhonebookTheme.green : PhonebookTheme.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PhonebookCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(a.student != null ? Icons.person_rounded : Icons.place_rounded, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showItem)
                    Text(
                      a.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: PhonebookTheme.ink),
                    ),
                  Text(
                    showItem ? who : (a.isBulk ? '$who · ${a.quantity} ${a.unit}' : who),
                    style: TextStyle(
                      fontWeight: showItem ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 14,
                      color: showItem ? PhonebookTheme.slate : PhonebookTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$since – $until${a.closeReason == null ? '' : ' · ${a.closeReason}'}',
                    style: const TextStyle(fontSize: 12, color: PhonebookTheme.muted),
                  ),
                  if (cond.isNotEmpty)
                    Text(cond, style: const TextStyle(fontSize: 11.5, color: PhonebookTheme.muted)),
                ],
              ),
            ),
            if (a.isOpen) ...[
              const AmenityChip('Current', color: PhonebookTheme.green),
              const SizedBox(width: 4),
            ],
            ?trailing,
          ],
        ),
      ),
    );
  }
}
