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
    this.listing = ClientListing.unlisted,
    this.specialDate,
    this.specialOccasion,
    this.specialOccasionNote,
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

  /// Whether this client is on the company's approved list. See
  /// [ClientListing].
  final ClientListing listing;

  /// Birthday or anniversary — the date a rep is expected to remember. Carried
  /// on the client because it belongs to the relationship, not to any visit.
  final DateTime? specialDate;

  /// What [specialDate] marks. Null only on records made before the occasion
  /// was captured — the form requires it alongside a date.
  final SpecialOccasion? specialOccasion;

  /// What the occasion is, when it is [SpecialOccasion.other].
  final String? specialOccasionNote;

  final DateTime? lastVisitAt;
  final DateTime? nextPlannedVisitAt;
  final int totalVisits;

  /// The MR who owns this relationship.
  final String? ownerEmployeeId;

  final DateTime? createdAt;
  final SyncStatus syncStatus;

  /// "Birthday", or the typed note for an "other" occasion. Null when there is
  /// no date to describe.
  String? get occasionLabel {
    if (specialDate == null) return null;
    if (specialOccasion == SpecialOccasion.other) {
      final note = specialOccasionNote?.trim();
      return (note == null || note.isEmpty) ? 'Special date' : note;
    }
    return specialOccasion?.label ?? 'Special date';
  }

  /// Days until the next time this date comes round, ignoring the year — 0 on
  /// the day itself.
  ///
  /// Whole days from *today*, not from now: a birthday is a day, not an
  /// instant, and comparing timestamps makes "tomorrow" flip to "today" at an
  /// arbitrary hour.
  int? daysUntilOccasion({DateTime? now}) {
    final date = specialDate;
    if (date == null) return null;

    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);

    var next = DateTime(start.year, date.month, date.day);
    if (next.isBefore(start)) {
      next = DateTime(start.year + 1, date.month, date.day);
    }

    return next.difference(start).inDays;
  }

  GeoPoint? get location => (latitude != null && longitude != null)
      ? GeoPoint(latitude!, longitude!)
      : null;

  /// "Cardiologist" — the standard metadata line.
  ///
  /// The category used to be appended here, and both places that render this
  /// line also render a category badge beside it: the row said "Core Target"
  /// twice, and on a narrow card the badge squeezed the duplicate until it
  /// ellipsised mid-word. One fact, one place — the badge keeps it, because a
  /// pill with a colour says it faster than the tail of a sentence.
  String get subtitle =>
      (specialty != null && specialty!.isNotEmpty) ? specialty! : type.label;

  String get fullAddress {
    return [
      addressLine,
      areaName,
      city,
      pincode,
    ].where((p) => p != null && p.isNotEmpty).join(', ');
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
    ClientListing? listing,
    DateTime? specialDate,
    SpecialOccasion? specialOccasion,
    String? specialOccasionNote,
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
      // These three were missing, and their absence was silent: every
      // `copyWith` reset the category to unlisted and wiped the special date,
      // because the constructor simply defaulted them. Nothing called it on a
      // client yet, so nothing had lost data — editing would have been the
      // first thing to.
      listing: listing ?? this.listing,
      specialDate: specialDate ?? this.specialDate,
      specialOccasion: specialOccasion ?? this.specialOccasion,
      specialOccasionNote: specialOccasionNote ?? this.specialOccasionNote,
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
