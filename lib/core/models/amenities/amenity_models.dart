/// Amenities Management models (`/api/amenities`, see
/// docs/AMENITIES_BACKEND_PROMPT.md). Everything per kind of asset is data
/// (categories, types); only these enums are fixed.
library;

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _intOrNull(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String? _str(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}

bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
DateTime? _time(dynamic v) => DateTime.tryParse('${v ?? ''}');
List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

/// Is it working?
enum AssetStatus {
  active,
  issueReported,
  inspectionRequired,
  underRepair,
  damaged,
  lost,
  retired;

  String get api => switch (this) {
        AssetStatus.issueReported => 'issue_reported',
        AssetStatus.inspectionRequired => 'inspection_required',
        AssetStatus.underRepair => 'under_repair',
        _ => name,
      };

  static AssetStatus parse(dynamic v) =>
      AssetStatus.values.firstWhere((s) => s.api == '$v', orElse: () => AssetStatus.active);
}

/// What shape is it in?
enum AssetCondition {
  newItem,
  good,
  fair,
  poor,
  unusable;

  String get api => this == AssetCondition.newItem ? 'new' : name;

  static AssetCondition? parse(dynamic v) {
    if (v == null) return null;
    for (final c in AssetCondition.values) {
      if (c.api == '$v') return c;
    }
    return null;
  }
}

/// Where is it? (derived by the server from the open assignment)
enum AssetPlacement {
  inStore,
  withStudent,
  installed;

  String get api => switch (this) {
        AssetPlacement.inStore => 'in_store',
        AssetPlacement.withStudent => 'with_student',
        AssetPlacement.installed => 'installed',
      };

  static AssetPlacement parse(dynamic v) =>
      AssetPlacement.values.firstWhere((p) => p.api == '$v', orElse: () => AssetPlacement.inStore);
}

enum TrackingMode {
  individual,
  bulk;

  static TrackingMode parse(dynamic v) => '$v' == 'bulk' ? TrackingMode.bulk : TrackingMode.individual;
}

/// States a bulk unit can be in (stock moves go from one to another).
enum BulkState {
  available,
  assigned,
  underRepair,
  damaged,
  lost,
  retired;

  String get api => this == BulkState.underRepair ? 'under_repair' : name;
}

enum LocationKind {
  building,
  wing,
  floor,
  room,
  area;

  static LocationKind parse(dynamic v) =>
      LocationKind.values.firstWhere((k) => k.name == '$v', orElse: () => LocationKind.area);
}

class AmenityCategory {
  final int id;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final int typeCount;
  final int assetCount;
  final int bulkUnits;

  const AmenityCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    this.typeCount = 0,
    this.assetCount = 0,
    this.bulkUnits = 0,
  });

  factory AmenityCategory.fromJson(Map<String, dynamic> j) => AmenityCategory(
        id: _int(j['id']),
        name: _str(j['name']) ?? 'Category',
        description: _str(j['description']),
        icon: _str(j['icon']),
        color: _str(j['color']),
        sortOrder: _int(j['sort_order']),
        isActive: j['is_active'] == null || _bool(j['is_active']),
        typeCount: _int(j['type_count']),
        assetCount: _int(j['asset_count']),
        bulkUnits: _int(j['bulk_units']),
      );
}

/// Inventory counts of a type (individual: assets per state; bulk: units).
class TypeInventory {
  final Map<String, int> counts;
  final String value;

  const TypeInventory({this.counts = const {}, this.value = '0'});

  int operator [](String key) => counts[key] ?? 0;

  factory TypeInventory.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TypeInventory();
    final counts = <String, int>{};
    j.forEach((k, v) {
      if (k != 'value' && v is num) counts[k] = v.toInt();
    });
    return TypeInventory(counts: counts, value: _str(j['value']) ?? '0');
  }
}

class AmenityType {
  final int id;
  final int categoryId;
  final String? categoryName;
  final String name;
  final String codePrefix;
  final TrackingMode tracking;
  final String unit;
  final String? description;
  final int? defaultExpectedLifeMonths;
  final int? maintenanceIntervalDays;
  final bool assignableToStudents;
  final bool isActive;
  final TypeInventory inventory;

  const AmenityType({
    required this.id,
    required this.categoryId,
    this.categoryName,
    required this.name,
    required this.codePrefix,
    required this.tracking,
    this.unit = 'pcs',
    this.description,
    this.defaultExpectedLifeMonths,
    this.maintenanceIntervalDays,
    this.assignableToStudents = false,
    this.isActive = true,
    this.inventory = const TypeInventory(),
  });

  bool get isBulk => tracking == TrackingMode.bulk;

  factory AmenityType.fromJson(Map<String, dynamic> j) => AmenityType(
        id: _int(j['id']),
        categoryId: _int(j['category_id']),
        categoryName: _str(j['category_name']),
        name: _str(j['name']) ?? 'Amenity',
        codePrefix: _str(j['code_prefix']) ?? '',
        tracking: TrackingMode.parse(j['tracking']),
        unit: _str(j['unit']) ?? 'pcs',
        description: _str(j['description']),
        defaultExpectedLifeMonths: _intOrNull(j['default_expected_life_months']),
        maintenanceIntervalDays: _intOrNull(j['maintenance_interval_days']),
        assignableToStudents: _bool(j['assignable_to_students']),
        isActive: j['is_active'] == null || _bool(j['is_active']),
        inventory: TypeInventory.fromJson(_map(j['inventory'])),
      );
}

class AmenityLocation {
  final int id;
  final int? parentId;
  final LocationKind kind;
  final String name;
  final String? roomNumber;
  final String path;
  final bool isActive;
  final int assetCount;
  final List<AmenityLocation> children;

  const AmenityLocation({
    required this.id,
    this.parentId,
    required this.kind,
    required this.name,
    this.roomNumber,
    required this.path,
    this.isActive = true,
    this.assetCount = 0,
    this.children = const [],
  });

  factory AmenityLocation.fromJson(Map<String, dynamic> j) => AmenityLocation(
        id: _int(j['id']),
        parentId: _intOrNull(j['parent_id']),
        kind: LocationKind.parse(j['kind']),
        name: _str(j['name']) ?? '',
        roomNumber: _str(j['room_number']),
        path: _str(j['path']) ?? _str(j['name']) ?? '',
        isActive: j['is_active'] == null || _bool(j['is_active']),
        assetCount: _int(j['asset_count']),
        children: _maps(j['children']).map(AmenityLocation.fromJson).toList(),
      );

  /// This node and everything under it, depth first.
  Iterable<AmenityLocation> flatten() sync* {
    yield this;
    for (final c in children) {
      yield* c.flatten();
    }
  }
}

class StudentBrief {
  final int id;
  final String name;
  final String? room;

  const StudentBrief({required this.id, required this.name, this.room});

  static StudentBrief? fromJson(Map<String, dynamic>? j) =>
      j == null ? null : StudentBrief(id: _int(j['id']), name: _str(j['name']) ?? 'Student', room: _str(j['room']));
}

class LocationBrief {
  final int id;
  final String path;

  const LocationBrief({required this.id, required this.path});

  static LocationBrief? fromJson(Map<String, dynamic>? j) =>
      j == null ? null : LocationBrief(id: _int(j['id']), path: _str(j['path']) ?? '');
}

/// The asset part of an assignment (null for bulk).
class AssetBrief {
  final int id;
  final String assetCode;
  final int typeId;
  final String typeName;
  final String? categoryName;
  final String? label;
  final String? serialNumber;
  final AssetStatus status;

  const AssetBrief({
    required this.id,
    required this.assetCode,
    required this.typeId,
    required this.typeName,
    this.categoryName,
    this.label,
    this.serialNumber,
    this.status = AssetStatus.active,
  });

  static AssetBrief? fromJson(Map<String, dynamic>? j) => j == null
      ? null
      : AssetBrief(
          id: _int(j['id']),
          assetCode: _str(j['asset_code']) ?? '',
          typeId: _int(j['type_id']),
          typeName: _str(j['type_name']) ?? '',
          categoryName: _str(j['category_name']),
          label: _str(j['label']),
          serialNumber: _str(j['serial_number']),
          status: AssetStatus.parse(j['status']),
        );
}

/// An item (asset) or a quantity (bulk) given to a student or installed at a
/// location. Closed ones are history and never change.
class AmenityAssignment {
  final int id;
  final AssetBrief? asset;
  final int? typeId;
  final String typeName;
  final String unit;
  final int quantity;
  final int returnedQuantity;
  final StudentBrief? student;
  final LocationBrief? location;
  final String? roomNumber;
  final DateTime? assignedAt;
  final String? assignedByName;
  final AssetCondition? conditionAtAssignment;
  final String? expectedReturnDate;
  final String? notes;
  final DateTime? closedAt;
  final String? closedByName;
  final String? closeReason;
  final AssetCondition? conditionAtReturn;
  final String? returnNote;

  const AmenityAssignment({
    required this.id,
    this.asset,
    this.typeId,
    this.typeName = '',
    this.unit = 'pcs',
    this.quantity = 1,
    this.returnedQuantity = 0,
    this.student,
    this.location,
    this.roomNumber,
    this.assignedAt,
    this.assignedByName,
    this.conditionAtAssignment,
    this.expectedReturnDate,
    this.notes,
    this.closedAt,
    this.closedByName,
    this.closeReason,
    this.conditionAtReturn,
    this.returnNote,
  });

  bool get isOpen => closedAt == null;
  bool get isBulk => asset == null;
  int get outstanding => quantity - returnedQuantity;

  /// "Room Key · HSH-RKEY-00012" or "Plastic Chair × 2".
  String get title => asset != null
      ? '${asset!.typeName} · ${asset!.assetCode}'
      : '$typeName × ${isOpen ? outstanding : quantity}';

  factory AmenityAssignment.fromJson(Map<String, dynamic> j) {
    final type = _map(j['type']);
    final asset = AssetBrief.fromJson(_map(j['asset']));
    return AmenityAssignment(
      id: _int(j['id'] ?? j['assignment_id']),
      asset: asset,
      typeId: _intOrNull(type?['id']) ?? asset?.typeId,
      typeName: _str(type?['name']) ?? asset?.typeName ?? '',
      unit: _str(type?['unit']) ?? 'pcs',
      quantity: j['quantity'] == null ? 1 : _int(j['quantity']),
      returnedQuantity: _int(j['returned_quantity']),
      student: StudentBrief.fromJson(_map(j['student'])),
      location: LocationBrief.fromJson(_map(j['location'])),
      roomNumber: _str(j['room_number']),
      assignedAt: _time(j['assigned_at']),
      assignedByName: _str(j['assigned_by_name']),
      conditionAtAssignment: AssetCondition.parse(j['condition_at_assignment']),
      expectedReturnDate: _str(j['expected_return_date']),
      notes: _str(j['notes']),
      closedAt: _time(j['closed_at']),
      closedByName: _str(j['closed_by_name']),
      closeReason: _str(j['close_reason']),
      conditionAtReturn: AssetCondition.parse(j['condition_at_return']),
      returnNote: _str(j['return_note']),
    );
  }
}

class AmenityAsset {
  final int id;
  final String assetCode;
  final int typeId;
  final String typeName;
  final int? categoryId;
  final String? categoryName;
  final String? label;
  final String? serialNumber;
  final AssetStatus status;
  final AssetCondition? condition;
  final AssetPlacement placement;
  final AmenityAssignment? currentAssignment;
  final LocationBrief? homeLocation;
  final String? purchaseDate;
  final String? installationDate;
  final String? purchaseCost;
  final String? vendor;
  final String? warrantyExpiry;
  final String? warranty; // expired | expiring | active | none
  final int? expectedLifeMonths;
  final String? replacementDue;
  final int? ageMonths;
  final String? nextMaintenanceDue;
  final bool maintenanceDue;
  final int maintenanceCount;
  final String? maintenanceCostTotal;
  final String? notes;
  final String? qrPayload;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? updatedAt;
  final String? updatedByName;

  const AmenityAsset({
    required this.id,
    required this.assetCode,
    required this.typeId,
    required this.typeName,
    this.categoryId,
    this.categoryName,
    this.label,
    this.serialNumber,
    this.status = AssetStatus.active,
    this.condition,
    this.placement = AssetPlacement.inStore,
    this.currentAssignment,
    this.homeLocation,
    this.purchaseDate,
    this.installationDate,
    this.purchaseCost,
    this.vendor,
    this.warrantyExpiry,
    this.warranty,
    this.expectedLifeMonths,
    this.replacementDue,
    this.ageMonths,
    this.nextMaintenanceDue,
    this.maintenanceDue = false,
    this.maintenanceCount = 0,
    this.maintenanceCostTotal,
    this.notes,
    this.qrPayload,
    this.createdAt,
    this.createdByName,
    this.updatedAt,
    this.updatedByName,
  });

  bool get isRetired => status == AssetStatus.retired;

  factory AmenityAsset.fromJson(Map<String, dynamic> j) => AmenityAsset(
        id: _int(j['id']),
        assetCode: _str(j['asset_code']) ?? '',
        typeId: _int(j['type_id']),
        typeName: _str(j['type_name']) ?? '',
        categoryId: _intOrNull(j['category_id']),
        categoryName: _str(j['category_name']),
        label: _str(j['label']),
        serialNumber: _str(j['serial_number']),
        status: AssetStatus.parse(j['status']),
        condition: AssetCondition.parse(j['condition']),
        placement: AssetPlacement.parse(j['placement']),
        currentAssignment: _map(j['current_assignment']) == null ? null : AmenityAssignment.fromJson(_map(j['current_assignment'])!),
        homeLocation: LocationBrief.fromJson(_map(j['home_location'])),
        purchaseDate: _str(j['purchase_date']),
        installationDate: _str(j['installation_date']),
        purchaseCost: _str(j['purchase_cost']),
        vendor: _str(j['vendor']),
        warrantyExpiry: _str(j['warranty_expiry']),
        warranty: _str(j['warranty']),
        expectedLifeMonths: _intOrNull(j['expected_life_months']),
        replacementDue: _str(j['replacement_due']),
        ageMonths: _intOrNull(j['age_months']),
        nextMaintenanceDue: _str(j['next_maintenance_due']),
        maintenanceDue: _bool(j['maintenance_due']),
        maintenanceCount: _int(j['maintenance_count']),
        maintenanceCostTotal: _str(j['maintenance_cost_total']),
        notes: _str(j['notes']),
        qrPayload: _str(j['qr_payload']),
        createdAt: _time(j['created_at']),
        createdByName: _str(j['created_by_name']),
        updatedAt: _time(j['updated_at']),
        updatedByName: _str(j['updated_by_name']),
      );
}

/// One lifecycle / activity entry. Append-only on the server.
class AmenityEvent {
  final int id;
  final String event;
  final String? happenedOn;
  final DateTime? at;
  final String? byName;
  final String? note;
  final Map<String, dynamic> data;
  final int? assetId;
  final String? assetCode;

  const AmenityEvent({
    required this.id,
    required this.event,
    this.happenedOn,
    this.at,
    this.byName,
    this.note,
    this.data = const {},
    this.assetId,
    this.assetCode,
  });

  factory AmenityEvent.fromJson(Map<String, dynamic> j) => AmenityEvent(
        id: _int(j['id']),
        event: _str(j['event']) ?? 'edited',
        happenedOn: _str(j['happened_on']),
        at: _time(j['at']),
        byName: _str(j['by_name']),
        note: _str(j['note']),
        data: _map(j['data']) ?? const {},
        assetId: _intOrNull(j['asset_id']),
        assetCode: _str(j['asset_code']),
      );
}

class Paged<T> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  const Paged({this.items = const [], this.total = 0, this.limit = 50, this.offset = 0});

  bool get hasMore => offset + items.length < total;

  static Paged<T> fromJson<T>(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) {
    final items = _maps(j['items']).map(item).toList();
    return Paged<T>(
      items: items,
      total: j['total'] == null ? items.length : _int(j['total']),
      limit: j['limit'] == null ? items.length : _int(j['limit']),
      offset: _int(j['offset']),
    );
  }
}

class StudentAmenities {
  final List<AmenityAssignment> current;
  final List<AmenityAssignment> returned;
  final List<AmenityAssignment> lostOrDamaged;

  const StudentAmenities({this.current = const [], this.returned = const [], this.lostOrDamaged = const []});

  bool get isEmpty => current.isEmpty && returned.isEmpty && lostOrDamaged.isEmpty;

  factory StudentAmenities.fromJson(Map<String, dynamic> j) => StudentAmenities(
        current: _maps(j['current']).map(AmenityAssignment.fromJson).toList(),
        returned: _maps(j['returned']).map(AmenityAssignment.fromJson).toList(),
        lostOrDamaged: _maps(j['lost_or_damaged']).map(AmenityAssignment.fromJson).toList(),
      );
}

class LocationAmenities {
  final AmenityLocation? location;
  final List<AmenityAssignment> installed;
  final List<AmenityAsset> homeAssets;
  final List<({StudentBrief student, List<AmenityAssignment> items})> residents;

  const LocationAmenities({this.location, this.installed = const [], this.homeAssets = const [], this.residents = const []});

  factory LocationAmenities.fromJson(Map<String, dynamic> j) => LocationAmenities(
        location: _map(j['location']) == null ? null : AmenityLocation.fromJson(_map(j['location'])!),
        installed: _maps(j['installed']).map(AmenityAssignment.fromJson).toList(),
        homeAssets: _maps(j['home_assets']).map(AmenityAsset.fromJson).toList(),
        residents: [
          for (final r in _maps(j['residents']))
            if (StudentBrief.fromJson(_map(r['student'])) case final s?)
              (student: s, items: _maps(r['items']).map(AmenityAssignment.fromJson).toList()),
        ],
      );
}

class AmenitiesDashboard {
  final Map<String, int> totals;
  final String value;
  final List<AmenityCategory> categories;
  final Map<int, String> categoryValues;

  const AmenitiesDashboard({this.totals = const {}, this.value = '0', this.categories = const [], this.categoryValues = const {}});

  int operator [](String key) => totals[key] ?? 0;

  factory AmenitiesDashboard.fromJson(Map<String, dynamic> j) {
    final t = _map(j['totals']) ?? const {};
    final totals = <String, int>{};
    t.forEach((k, v) {
      if (k != 'value' && v is num) totals[k] = v.toInt();
    });
    final cats = _maps(j['categories']);
    return AmenitiesDashboard(
      totals: totals,
      value: _str(t['value']) ?? '0',
      categories: [
        for (final c in cats)
          AmenityCategory.fromJson({...c, 'asset_count': c['assets'] ?? c['asset_count'], 'bulk_units': c['bulk_units']}),
      ],
      categoryValues: {for (final c in cats) _int(c['id']): _str(c['value']) ?? '0'},
    );
  }
}
