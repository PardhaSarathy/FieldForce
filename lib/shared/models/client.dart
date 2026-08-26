import '../../core/location/geo_math.dart';
import '../enums/app_enums.dart';

/// A doctor, hospital, chemist or stockist the field team calls on (§19).
class Client {
  const Client({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.areaId,
    required this.areaName,
    required this.territoryId,
    this.specialty,
    this.designation,
    this.contactPerson,
    this.mobile,
    this.email,
    this.addressLine,
    this.city,
    this.pincode,
    this.latitude,
    this.longitude,
    this.clusterId,
    this.clusterName,
    this.isActive = true,
    this.lastVisitAt,
    this.nextPlannedVisitAt,
    this.totalVisits = 0,
    this.ownerEmployeeId,
    this.createdAt,
    this.syncStatus = SyncStatus.synced,
  });

  final String id;
  final String name;
  final ClientType type;
  final ClientCategory category;
  final String areaId;
  final String areaName;
  final String territoryId;
  final String? specialty;
  final String? designation;
  final String? contactPerson;
  final String? mobile;
  final String? email;
  final String? addressLine;
  final String? city;
  final String? pincode;

  /// Registered location, captured at client creation. The geo-fence for every
  /// visit is measured against this point (§9).
  final double? latitude;
  final double? longitude;

  final String? clusterId;
  final String? clusterName;
  final bool isActive;
  final DateTime? lastVisitAt;
  final DateTime? nextPlannedVisitAt;
  final int totalVisits;

  /// The MR who owns this relationship.
  final String? ownerEmployeeId;

  final DateTime? createdAt;
  final SyncStatus syncStatus;

  GeoPoint? get location =>
      (latitude != null && longitude != null) ? GeoPoint(latitude!, longitude!) : null;

  /// "Cardiologist · Core Target" — the standard metadata line.
  String get subtitle {
    final parts = <String>[
      if (specialty != null && specialty!.isNotEmpty) specialty! else type.label,
      category.label,
    ];
    return parts.join(' · ');
  }

  String get fullAddress {
    return [addressLine, areaName, city, pincode]
        .where((p) => p != null && p.isNotEmpty)
        .join(', ');
  }

  Client copyWith({
    String? name,
    ClientType? type,
    ClientCategory? category,
    String? specialty,
    String? designation,
    String? contactPerson,
    String? mobile,
    String? email,
    String? addressLine,
    String? city,
    String? pincode,
    double? latitude,
    double? longitude,
    String? areaId,
    String? areaName,
    String? clusterId,
    String? clusterName,
    bool? isActive,
    DateTime? lastVisitAt,
    DateTime? nextPlannedVisitAt,
    int? totalVisits,
    SyncStatus? syncStatus,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      areaId: areaId ?? this.areaId,
      areaName: areaName ?? this.areaName,
      territoryId: territoryId,
      specialty: specialty ?? this.specialty,
      designation: designation ?? this.designation,
      contactPerson: contactPerson ?? this.contactPerson,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      clusterId: clusterId ?? this.clusterId,
      clusterName: clusterName ?? this.clusterName,
      isActive: isActive ?? this.isActive,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      nextPlannedVisitAt: nextPlannedVisitAt ?? this.nextPlannedVisitAt,
      totalVisits: totalVisits ?? this.totalVisits,
      ownerEmployeeId: ownerEmployeeId,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// A product in the company catalogue, used by RCPA, orders and resources.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.mrp,
    this.division,
    this.composition,
    this.packSize,
    this.gstPercent = 12,
    this.description,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String code;
  final double mrp;
  final String? division;
  final String? composition;
  final String? packSize;
  final double gstPercent;
  final String? description;
  final bool isActive;
}
