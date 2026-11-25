class SpaceSummary {
  final int totalSpaces;
  final int totalAssets;
  final int workingAssets;
  final int faultyAssets;
  final int underRepairAssets;
  final int awaitingReplacementAssets;
  final int openComplaints;
  final int pendingComplaints;
  final int inProgressComplaints;
  final int resolvedComplaints;
  final double? totalMaintenanceCost;
  final int totalMaintenanceRecords;

  const SpaceSummary({
    required this.totalSpaces,
    required this.totalAssets,
    required this.workingAssets,
    required this.faultyAssets,
    required this.underRepairAssets,
    required this.awaitingReplacementAssets,
    required this.openComplaints,
    required this.pendingComplaints,
    required this.inProgressComplaints,
    required this.resolvedComplaints,
    this.totalMaintenanceCost,
    required this.totalMaintenanceRecords,
  });

  factory SpaceSummary.fromJson(Map<String, dynamic> j) => SpaceSummary(
        totalSpaces: _asInt(j['total_spaces']),
        totalAssets: _asInt(j['total_assets']),
        workingAssets: _asInt(j['working_assets']),
        faultyAssets: _asInt(j['faulty_assets']),
        underRepairAssets: _asInt(j['under_repair_assets']),
        awaitingReplacementAssets: _asInt(j['awaiting_replacement_assets']),
        openComplaints: _asInt(j['open_complaints']),
        pendingComplaints: _asInt(j['pending_complaints']),
        inProgressComplaints: _asInt(j['in_progress_complaints']),
        resolvedComplaints: _asInt(j['resolved_complaints']),
        totalMaintenanceCost: _asDouble(j['total_maintenance_cost']),
        totalMaintenanceRecords: _asInt(j['total_maintenance_records']),
      );
}

class FloorOverviewItem {
  final int floorId;
  final String floorName;
  final int totalSpaces;
  final int studentRoomsCount;
  final int totalAssets;
  final int workingAssets;
  final int faultyAssets;
  final int openIssues;
  final String healthStatus;
  final List<String> specialSpaces;
  final String subtitle;

  const FloorOverviewItem({
    required this.floorId,
    required this.floorName,
    required this.totalSpaces,
    required this.studentRoomsCount,
    required this.totalAssets,
    required this.workingAssets,
    required this.faultyAssets,
    required this.openIssues,
    required this.healthStatus,
    required this.specialSpaces,
    required this.subtitle,
  });

  factory FloorOverviewItem.fromJson(Map<String, dynamic> j) => FloorOverviewItem(
        floorId: _asInt(j['floor_id']),
        floorName: (j['floor_name'] ?? '').toString(),
        totalSpaces: _asInt(j['total_spaces']),
        studentRoomsCount: _asInt(j['student_rooms_count']),
        totalAssets: _asInt(j['total_assets']),
        workingAssets: _asInt(j['working_assets']),
        faultyAssets: _asInt(j['faulty_assets']),
        openIssues: _asInt(j['open_issues']),
        healthStatus: (j['health_status'] ?? 'healthy').toString(),
        specialSpaces: (j['special_spaces'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        subtitle: (j['subtitle'] ?? '').toString(),
      );
}

class SpaceOverviewResponse {
  final SpaceSummary summary;
  final List<FloorOverviewItem> floors;

  const SpaceOverviewResponse({required this.summary, required this.floors});

  factory SpaceOverviewResponse.fromJson(Map<String, dynamic> j) => SpaceOverviewResponse(
        summary: SpaceSummary.fromJson(Map<String, dynamic>.from((j['summary'] as Map?) ?? const {})),
        floors: ((j['floors'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FloorOverviewItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class SpaceTypeModel {
  final int id;
  final String name;
  final String slug;
  final String iconKey;
  final bool isStudentRoom;
  final int? defaultCapacity;
  final bool isActive;

  const SpaceTypeModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconKey,
    required this.isStudentRoom,
    this.defaultCapacity,
    this.isActive = true,
  });

  factory SpaceTypeModel.fromJson(Map<String, dynamic> j) => SpaceTypeModel(
        id: _asInt(j['id']),
        name: (j['name'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        iconKey: (j['icon_key'] ?? 'meeting_room').toString(),
        isStudentRoom: _asBool(j['is_student_room']),
        defaultCapacity: _asIntOrNull(j['default_capacity']),
        isActive: j['is_active'] == null ? true : _asBool(j['is_active']),
      );
}

class SpaceCardItem {
  final int id;
  final int floorId;
  final String floorName;
  final int spaceTypeId;
  final String spaceTypeName;
  final String spaceTypeSlug;
  final String spaceTypeIcon;
  final bool isStudentRoom;
  final String name;
  final String? roomNumber;
  final int? capacity;
  final int residentCount;
  final String? description;
  final int totalAssets;
  final int workingAssets;
  final int faultyAssets;
  final int openIssues;
  final String maintenanceStatus;

  const SpaceCardItem({
    required this.id,
    required this.floorId,
    required this.floorName,
    required this.spaceTypeId,
    required this.spaceTypeName,
    required this.spaceTypeSlug,
    required this.spaceTypeIcon,
    required this.isStudentRoom,
    required this.name,
    this.roomNumber,
    this.capacity,
    this.residentCount = 0,
    this.description,
    required this.totalAssets,
    required this.workingAssets,
    required this.faultyAssets,
    required this.openIssues,
    required this.maintenanceStatus,
  });

  factory SpaceCardItem.fromJson(Map<String, dynamic> j) => SpaceCardItem(
        id: _asInt(j['id']),
        floorId: _asInt(j['floor_id']),
        floorName: (j['floor_name'] ?? '').toString(),
        spaceTypeId: _asInt(j['space_type_id']),
        spaceTypeName: (j['space_type_name'] ?? '').toString(),
        spaceTypeSlug: (j['space_type_slug'] ?? '').toString(),
        spaceTypeIcon: (j['space_type_icon'] ?? 'meeting_room').toString(),
        isStudentRoom: _asBool(j['is_student_room']),
        name: (j['name'] ?? '').toString(),
        roomNumber: _strOrNull(j['room_number']),
        capacity: _asIntOrNull(j['capacity']),
        residentCount: _asInt(j['resident_count']),
        description: _strOrNull(j['description']),
        totalAssets: _asInt(j['total_assets']),
        workingAssets: _asInt(j['working_assets']),
        faultyAssets: _asInt(j['faulty_assets']),
        openIssues: _asInt(j['open_issues']),
        maintenanceStatus: (j['maintenance_status'] ?? 'ok').toString(),
      );
}

class FloorDetailsResponse {
  final int floorId;
  final String floorName;
  final int totalSpaces;
  final int totalAssets;
  final int faultyAssets;
  final int openIssues;
  final List<SpaceTypeModel> spaceTypes;
  final List<SpaceCardItem> spaces;

  const FloorDetailsResponse({
    required this.floorId,
    required this.floorName,
    required this.totalSpaces,
    required this.totalAssets,
    required this.faultyAssets,
    required this.openIssues,
    required this.spaceTypes,
    required this.spaces,
  });

  factory FloorDetailsResponse.fromJson(Map<String, dynamic> j) {
    final fl = Map<String, dynamic>.from((j['floor'] as Map?) ?? const {});
    return FloorDetailsResponse(
      floorId: _asInt(fl['floor_id']),
      floorName: (fl['floor_name'] ?? '').toString(),
      totalSpaces: _asInt(fl['total_spaces']),
      totalAssets: _asInt(fl['total_assets']),
      faultyAssets: _asInt(fl['faulty_assets']),
      openIssues: _asInt(fl['open_issues']),
      spaceTypes: ((j['space_types'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SpaceTypeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      spaces: ((j['spaces'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SpaceCardItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class SpaceInventorySummaryItem {
  final int typeId;
  final String typeName;
  final String typeIcon;
  final String categoryName;
  final int total;
  final int working;
  final int faulty;

  const SpaceInventorySummaryItem({
    required this.typeId,
    required this.typeName,
    required this.typeIcon,
    required this.categoryName,
    required this.total,
    required this.working,
    required this.faulty,
  });

  factory SpaceInventorySummaryItem.fromJson(Map<String, dynamic> j) => SpaceInventorySummaryItem(
        typeId: _asInt(j['type_id']),
        typeName: (j['type_name'] ?? '').toString(),
        typeIcon: (j['type_icon'] ?? 'inventory_2').toString(),
        categoryName: (j['category_name'] ?? '').toString(),
        total: _asInt(j['total']),
        working: _asInt(j['working']),
        faulty: _asInt(j['faulty']),
      );
}

class SpaceAssetModel {
  final int id;
  final String assetCode;
  final int typeId;
  final String typeName;
  final String typeIcon;
  final int categoryId;
  final String categoryName;
  final int? complaintCategoryId;
  final int? complaintItemId;
  final int spaceId;
  final String spaceName;
  final String? roomNumber;
  final int floorId;
  final String floorName;
  final String name;
  final String status;
  final String condition;
  final String? serialNumber;
  final String? manufacturer;
  final String? supplier;
  final String? purchaseDate;
  final double? purchaseCost;
  final String? installationDate;
  final int? warrantyMonths;
  final String? warrantyExpiresAt;
  final String warrantyStatus;
  final int? expectedLifeMonths;
  final String? nextMaintenanceAt;
  final String? photoUrl;
  final String? notes;
  final int? replacedByAssetId;
  final int? replacesAssetId;
  final bool isArchived;
  final int openComplaintsCount;
  final String? createdByName;
  final String? updatedByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpaceAssetModel({
    required this.id,
    required this.assetCode,
    required this.typeId,
    required this.typeName,
    required this.typeIcon,
    required this.categoryId,
    required this.categoryName,
    this.complaintCategoryId,
    this.complaintItemId,
    required this.spaceId,
    required this.spaceName,
    this.roomNumber,
    required this.floorId,
    required this.floorName,
    required this.name,
    required this.status,
    required this.condition,
    this.serialNumber,
    this.manufacturer,
    this.supplier,
    this.purchaseDate,
    this.purchaseCost,
    this.installationDate,
    this.warrantyMonths,
    this.warrantyExpiresAt,
    required this.warrantyStatus,
    this.expectedLifeMonths,
    this.nextMaintenanceAt,
    this.photoUrl,
    this.notes,
    this.replacedByAssetId,
    this.replacesAssetId,
    required this.isArchived,
    required this.openComplaintsCount,
    this.createdByName,
    this.updatedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory SpaceAssetModel.fromJson(Map<String, dynamic> j) => SpaceAssetModel(
        id: _asInt(j['id']),
        assetCode: (j['asset_code'] ?? '').toString(),
        typeId: _asInt(j['type_id']),
        typeName: (j['type_name'] ?? '').toString(),
        typeIcon: (j['type_icon'] ?? 'inventory_2').toString(),
        categoryId: _asInt(j['category_id']),
        categoryName: (j['category_name'] ?? '').toString(),
        complaintCategoryId: _asIntOrNull(j['complaint_category_id']),
        complaintItemId: _asIntOrNull(j['complaint_item_id']),
        spaceId: _asInt(j['space_id']),
        spaceName: (j['space_name'] ?? '').toString(),
        roomNumber: _strOrNull(j['room_number']),
        floorId: _asInt(j['floor_id']),
        floorName: (j['floor_name'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        status: (j['status'] ?? 'working').toString(),
        condition: (j['condition'] ?? 'good').toString(),
        serialNumber: _strOrNull(j['serial_number']),
        manufacturer: _strOrNull(j['manufacturer']),
        supplier: _strOrNull(j['supplier']),
        purchaseDate: _strOrNull(j['purchase_date']),
        purchaseCost: _asDouble(j['purchase_cost']),
        installationDate: _strOrNull(j['installation_date']),
        warrantyMonths: _asIntOrNull(j['warranty_months']),
        warrantyExpiresAt: _strOrNull(j['warranty_expires_at']),
        warrantyStatus: (j['warranty_status'] ?? 'none').toString(),
        expectedLifeMonths: _asIntOrNull(j['expected_life_months']),
        nextMaintenanceAt: _strOrNull(j['next_maintenance_at']),
        photoUrl: _strOrNull(j['photo_url']),
        notes: _strOrNull(j['notes']),
        replacedByAssetId: _asIntOrNull(j['replaced_by_asset_id']),
        replacesAssetId: _asIntOrNull(j['replaces_asset_id']),
        isArchived: _asBool(j['is_archived']),
        openComplaintsCount: _asInt(j['open_complaints_count']),
        createdByName: _strOrNull(j['created_by_name']),
        updatedByName: _strOrNull(j['updated_by_name']),
        createdAt: _asDate(j['created_at']),
        updatedAt: _asDate(j['updated_at']),
      );
}

class SpaceAssignedStudent {
  final int id;
  final String name;
  final String studentCode;
  final String roomNumber;

  const SpaceAssignedStudent({
    required this.id,
    required this.name,
    required this.studentCode,
    required this.roomNumber,
  });

  factory SpaceAssignedStudent.fromJson(Map<String, dynamic> j) => SpaceAssignedStudent(
        id: _asInt(j['id']),
        name: (j['name'] ?? '').toString(),
        studentCode: (j['student_code'] ?? '').toString(),
        roomNumber: (j['room_number'] ?? '').toString(),
      );
}

class SpaceDetailsResponse {
  final SpaceCardItem space;
  final int totalAssets;
  final int workingAssets;
  final int faultyAssets;
  final int openComplaintsCount;
  final List<SpaceInventorySummaryItem> inventorySummary;
  final List<SpaceAssetModel> assets;
  final List<SpaceAssetModel> archivedAssets;
  final List<SpaceAssignedStudent> assignedStudents;
  final List<Map<String, dynamic>> openComplaints;
  final List<Map<String, dynamic>> maintenanceHistory;
  final List<Map<String, dynamic>> previousAllocations;
  final List<Map<String, dynamic>> roomKeys;

  const SpaceDetailsResponse({
    required this.space,
    required this.totalAssets,
    required this.workingAssets,
    required this.faultyAssets,
    required this.openComplaintsCount,
    required this.inventorySummary,
    required this.assets,
    required this.archivedAssets,
    required this.assignedStudents,
    required this.openComplaints,
    required this.maintenanceHistory,
    required this.previousAllocations,
    required this.roomKeys,
  });

  factory SpaceDetailsResponse.fromJson(Map<String, dynamic> j) {
    final sum = Map<String, dynamic>.from((j['summary'] as Map?) ?? const {});
    return SpaceDetailsResponse(
      space: SpaceCardItem.fromJson(Map<String, dynamic>.from((j['space'] as Map?) ?? const {})),
      totalAssets: _asInt(sum['total_assets']),
      workingAssets: _asInt(sum['working_assets']),
      faultyAssets: _asInt(sum['faulty_assets']),
      openComplaintsCount: _asInt(sum['open_complaints']),
      inventorySummary: ((j['inventory_summary'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SpaceInventorySummaryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      assets: ((j['assets'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SpaceAssetModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      archivedAssets: ((j['archived_assets'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SpaceAssetModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      assignedStudents: ((j['assigned_students'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SpaceAssignedStudent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      openComplaints: ((j['open_complaints'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      maintenanceHistory: ((j['maintenance_history'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      previousAllocations: ((j['previous_allocations'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      roomKeys: ((j['room_keys'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}

class AssetEventModel {
  final int id;
  final String eventType;
  final String description;
  final String? fromSpaceName;
  final String? toSpaceName;
  final int? complaintId;
  final double? cost;
  final String? byName;
  final DateTime? createdAt;

  const AssetEventModel({
    required this.id,
    required this.eventType,
    required this.description,
    this.fromSpaceName,
    this.toSpaceName,
    this.complaintId,
    this.cost,
    this.byName,
    this.createdAt,
  });

  factory AssetEventModel.fromJson(Map<String, dynamic> j) => AssetEventModel(
        id: _asInt(j['id']),
        eventType: (j['event_type'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        fromSpaceName: _strOrNull(j['from_space_name']),
        toSpaceName: _strOrNull(j['to_space_name']),
        complaintId: _asIntOrNull(j['complaint_id']),
        cost: _asDouble(j['cost']),
        byName: _strOrNull(j['by_name']),
        createdAt: _asDate(j['created_at']),
      );
}

class AssetDetailsResponse {
  final SpaceAssetModel asset;
  final int totalRepairs;
  final double? totalMaintenanceCost;
  final int openComplaints;
  final String warrantyStatus;
  final String? warrantyExpiresAt;
  final Map<String, dynamic>? replacedBy;
  final Map<String, dynamic>? replacesAsset;
  final List<AssetEventModel> timeline;
  final List<Map<String, dynamic>> complaints;
  final List<Map<String, dynamic>> locationHistory;
  final List<Map<String, dynamic>> maintenanceRecords;

  const AssetDetailsResponse({
    required this.asset,
    required this.totalRepairs,
    this.totalMaintenanceCost,
    required this.openComplaints,
    required this.warrantyStatus,
    this.warrantyExpiresAt,
    this.replacedBy,
    this.replacesAsset,
    required this.timeline,
    required this.complaints,
    required this.locationHistory,
    required this.maintenanceRecords,
  });

  factory AssetDetailsResponse.fromJson(Map<String, dynamic> j) {
    final qs = Map<String, dynamic>.from((j['quick_stats'] as Map?) ?? const {});
    return AssetDetailsResponse(
      asset: SpaceAssetModel.fromJson(Map<String, dynamic>.from((j['asset'] as Map?) ?? const {})),
      totalRepairs: _asInt(qs['total_repairs']),
      totalMaintenanceCost: _asDouble(qs['total_maintenance_cost']),
      openComplaints: _asInt(qs['open_complaints']),
      warrantyStatus: (qs['warranty_status'] ?? 'none').toString(),
      warrantyExpiresAt: _strOrNull(qs['warranty_expires_at']),
      replacedBy: j['replaced_by'] is Map ? Map<String, dynamic>.from(j['replaced_by'] as Map) : null,
      replacesAsset: j['replaces_asset'] is Map ? Map<String, dynamic>.from(j['replaces_asset'] as Map) : null,
      timeline: ((j['timeline'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AssetEventModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      complaints: ((j['complaints'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      locationHistory: ((j['location_history'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      maintenanceRecords: ((j['maintenance_records'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}

class AmenityCategoryModel {
  final int id;
  final String name;
  final String iconKey;
  final int? complaintCategoryId;
  final bool isActive;

  const AmenityCategoryModel({
    required this.id,
    required this.name,
    required this.iconKey,
    this.complaintCategoryId,
    this.isActive = true,
  });

  factory AmenityCategoryModel.fromJson(Map<String, dynamic> j) => AmenityCategoryModel(
        id: _asInt(j['id']),
        name: (j['name'] ?? '').toString(),
        iconKey: (j['icon_key'] ?? 'category').toString(),
        complaintCategoryId: _asIntOrNull(j['complaint_category_id']),
        isActive: j['is_active'] == null ? true : _asBool(j['is_active']),
      );
}

class AmenityTypeModel {
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final String codePrefix;
  final String iconKey;
  final int? complaintItemId;
  final int? defaultLifeMonths;
  final int? defaultWarrantyMonths;
  final bool isActive;

  const AmenityTypeModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.codePrefix,
    required this.iconKey,
    this.complaintItemId,
    this.defaultLifeMonths,
    this.defaultWarrantyMonths,
    this.isActive = true,
  });

  factory AmenityTypeModel.fromJson(Map<String, dynamic> j) => AmenityTypeModel(
        id: _asInt(j['id']),
        categoryId: _asInt(j['category_id']),
        categoryName: (j['category_name'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        codePrefix: (j['code_prefix'] ?? '').toString(),
        iconKey: (j['icon_key'] ?? 'inventory_2').toString(),
        complaintItemId: _asIntOrNull(j['complaint_item_id']),
        defaultLifeMonths: _asIntOrNull(j['default_life_months']),
        defaultWarrantyMonths: _asIntOrNull(j['default_warranty_months']),
        isActive: j['is_active'] == null ? true : _asBool(j['is_active']),
      );
}

class MaintenanceWorkspaceItem {
  final int id;
  final String roomId;
  final int categoryId;
  final String category;
  final int itemId;
  final String item;
  final String? comment;
  final String status;
  final String priority;
  final int? spaceId;
  final String spaceName;
  final int floorId;
  final String floorName;
  final int? assetId;
  final String? assetCode;
  final String? assetName;
  final String? assetStatus;
  final String? assetCondition;
  final String assetIcon;
  final String? assignedSolverName;
  final String? studentName;
  final DateTime? createdAt;

  const MaintenanceWorkspaceItem({
    required this.id,
    required this.roomId,
    required this.categoryId,
    required this.category,
    required this.itemId,
    required this.item,
    this.comment,
    required this.status,
    required this.priority,
    this.spaceId,
    required this.spaceName,
    required this.floorId,
    required this.floorName,
    this.assetId,
    this.assetCode,
    this.assetName,
    this.assetStatus,
    this.assetCondition,
    required this.assetIcon,
    this.assignedSolverName,
    this.studentName,
    this.createdAt,
  });

  factory MaintenanceWorkspaceItem.fromJson(Map<String, dynamic> j) {
    final stu = j['student'] is Map ? j['student'] as Map : null;
    return MaintenanceWorkspaceItem(
      id: _asInt(j['id']),
      roomId: (j['room_id'] ?? '').toString(),
      categoryId: _asInt(j['category_id']),
      category: (j['category'] ?? '').toString(),
      itemId: _asInt(j['item_id']),
      item: (j['item'] ?? '').toString(),
      comment: _strOrNull(j['comment']),
      status: (j['status'] ?? 'OPEN').toString(),
      priority: (j['priority'] ?? 'medium').toString(),
      spaceId: _asIntOrNull(j['space_id']),
      spaceName: (j['space_name'] ?? '').toString(),
      floorId: _asInt(j['floor_id']),
      floorName: (j['floor_name'] ?? '').toString(),
      assetId: _asIntOrNull(j['asset_id']),
      assetCode: _strOrNull(j['asset_code']),
      assetName: _strOrNull(j['asset_name']),
      assetStatus: _strOrNull(j['asset_status']),
      assetCondition: _strOrNull(j['asset_condition']),
      assetIcon: (j['asset_icon'] ?? 'build_circle').toString(),
      assignedSolverName: _strOrNull(j['assigned_solver_name']),
      studentName: stu != null ? _strOrNull(stu['name']) : null,
      createdAt: _asDate(j['created_at']),
    );
  }
}

class MaintenanceWorkspaceResponse {
  final int open;
  final int inProgress;
  final int awaitingReplacement;
  final int completed;
  final List<MaintenanceWorkspaceItem> items;

  const MaintenanceWorkspaceResponse({
    required this.open,
    required this.inProgress,
    required this.awaitingReplacement,
    required this.completed,
    required this.items,
  });

  factory MaintenanceWorkspaceResponse.fromJson(Map<String, dynamic> j) {
    final sum = Map<String, dynamic>.from((j['summary'] as Map?) ?? const {});
    return MaintenanceWorkspaceResponse(
      open: _asInt(sum['open']),
      inProgress: _asInt(sum['in_progress']),
      awaitingReplacement: _asInt(sum['awaiting_replacement']),
      completed: _asInt(sum['completed']),
      items: ((j['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MaintenanceWorkspaceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class SpaceConfigResponse {
  final List<SpaceTypeModel> spaceTypes;
  final List<AmenityCategoryModel> categories;
  final List<AmenityTypeModel> types;
  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> schedules;
  final Map<String, dynamic> settings;

  const SpaceConfigResponse({
    required this.spaceTypes,
    required this.categories,
    required this.types,
    required this.templates,
    required this.schedules,
    required this.settings,
  });

  factory SpaceConfigResponse.fromJson(Map<String, dynamic> j) => SpaceConfigResponse(
        spaceTypes: ((j['space_types'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SpaceTypeModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        categories: ((j['categories'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AmenityCategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        types: ((j['types'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AmenityTypeModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        templates: ((j['templates'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        schedules: ((j['schedules'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        settings: Map<String, dynamic>.from((j['settings'] as Map?) ?? const {}),
      );
}

class StudentMySpaceResponse {
  final SpaceDetailsResponse? myRoom;
  final List<SpaceCardItem> commonSpaces;

  const StudentMySpaceResponse({this.myRoom, required this.commonSpaces});

  factory StudentMySpaceResponse.fromJson(Map<String, dynamic> j) => StudentMySpaceResponse(
        myRoom: j['my_room'] is Map
            ? SpaceDetailsResponse.fromJson(Map<String, dynamic>.from(j['my_room'] as Map))
            : null,
        commonSpaces: ((j['common_spaces'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SpaceCardItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

int _asInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _asIntOrNull(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
double? _asDouble(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
bool _asBool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';
String? _strOrNull(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
DateTime? _asDate(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
