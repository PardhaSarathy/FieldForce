import '../../core/location/geo_math.dart';
import '../enums/app_enums.dart';

/// One entry in an approval trail (§62, §69). Approval history is append-only:
/// a decision is never edited, only followed by another entry.
class ApprovalEvent {
  const ApprovalEvent({
    required this.status,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.at,
    this.reason,
    this.comment,
  });

  final ApprovalStatus status;
  final String actorId;
  final String actorName;
  final String actorRole;
  final DateTime at;

  /// Mandatory when [status] is rejected (§66.4).
  final String? reason;

  final String? comment;
}

/// Products discussed during a visit, with the competitor comparison that RCPA
/// (Retail Chemist Prescription Audit) captures.
class RcpaEntry {
  const RcpaEntry({
    required this.productId,
    required this.productName,
    this.ownQuantity = 0,
    this.competitorName,
    this.competitorQuantity = 0,
  });

  final String productId;
  final String productName;
  final int ownQuantity;
  final String? competitorName;
  final int competitorQuantity;

  /// Our share of the audited prescriptions for this molecule.
  double get sharePercent {
    final total = ownQuantity + competitorQuantity;
    return total == 0 ? 0 : (ownQuantity / total) * 100;
  }
}

/// A field activity — planned, in progress, or completed (§17).
///
/// This is the central transactional record of the product. A completed
/// activity feeds daily reports, client history, coverage metrics, manager
/// visibility and location history without any re-entry (§1).
class Activity {
  const Activity({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.clientId,
    required this.clientName,
    required this.scheduledStart,
    required this.status,
    this.clientSpecialty,
    this.clientType = ClientType.doctor,
    this.locationName,
    this.areaName,
    this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    this.workType = WorkType.fieldWork,
    this.purpose,
    this.contactPerson,
    this.contactMobile,
    this.feedback,
    this.remarks,
    this.pop,
    this.inputsGiven,
    this.pobAmount,
    this.rcpaScore,
    this.rcpaEntries = const [],
    this.productIds = const [],
    this.expectedNextVisit,
    this.geoResult,
    this.outOfRangeReason,
    this.photoPaths = const [],
    this.attachmentPaths = const [],
    this.syncStatus = SyncStatus.synced,
    this.dayPlanId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String clientId;
  final String clientName;
  final String? clientSpecialty;
  final ClientType clientType;
  final String? locationName;
  final String? areaName;

  final DateTime scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;

  final ActivityStatus status;
  final WorkType workType;
  final VisitPurpose? purpose;

  final String? contactPerson;
  final String? contactMobile;

  // ------------------------------------------------------------- feedback
  final String? feedback;
  final String? remarks;

  /// Point-of-promotion material shared during the call.
  final String? pop;

  /// Samples and promotional inputs handed over.
  final String? inputsGiven;

  /// Product order booked on the call, in rupees. Distinct from an Order
  /// record: this is what the doctor indicated, not what the chemist placed.
  final double? pobAmount;

  /// 1–5 star overall RCPA rating shown in the activity detail.
  final int? rcpaScore;

  final List<RcpaEntry> rcpaEntries;
  final List<String> productIds;
  final DateTime? expectedNextVisit;

  // ------------------------------------------------------------- location
  final GeoFenceResult? geoResult;

  /// Required when the visit was completed out of range under the `warn`
  /// policy — the justification is part of the audit record.
  final String? outOfRangeReason;

  final List<String> photoPaths;
  final List<String> attachmentPaths;

  final SyncStatus syncStatus;
  final String? dayPlanId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Duration? get duration {
    if (actualStart == null || actualEnd == null) return null;
    return actualEnd!.difference(actualStart!);
  }

  Duration get plannedDuration =>
      scheduledEnd?.difference(scheduledStart) ?? const Duration(minutes: 15);

  bool get isVerified => geoResult?.isVerified ?? false;

  /// True when the record should be visually flagged for a manager.
  bool get needsAttention =>
      status == ActivityStatus.missed ||
      syncStatus == SyncStatus.failed ||
      (status == ActivityStatus.completed && !isVerified);

  Activity copyWith({
    ActivityStatus? status,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? actualStart,
    DateTime? actualEnd,
    VisitPurpose? purpose,
    String? contactPerson,
    String? contactMobile,
    String? feedback,
    String? remarks,
    String? pop,
    int? rcpaScore,
    List<RcpaEntry>? rcpaEntries,
    List<String>? productIds,
    DateTime? expectedNextVisit,
    GeoFenceResult? geoResult,
    String? outOfRangeReason,
    List<String>? photoPaths,
    List<String>? attachmentPaths,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      clientId: clientId,
      clientName: clientName,
      clientSpecialty: clientSpecialty,
      clientType: clientType,
      locationName: locationName,
      areaName: areaName,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      status: status ?? this.status,
      workType: workType,
      purpose: purpose ?? this.purpose,
      contactPerson: contactPerson ?? this.contactPerson,
      contactMobile: contactMobile ?? this.contactMobile,
      feedback: feedback ?? this.feedback,
      remarks: remarks ?? this.remarks,
      pop: pop ?? this.pop,
      rcpaScore: rcpaScore ?? this.rcpaScore,
      rcpaEntries: rcpaEntries ?? this.rcpaEntries,
      productIds: productIds ?? this.productIds,
      expectedNextVisit: expectedNextVisit ?? this.expectedNextVisit,
      geoResult: geoResult ?? this.geoResult,
      outOfRangeReason: outOfRangeReason ?? this.outOfRangeReason,
      photoPaths: photoPaths ?? this.photoPaths,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      syncStatus: syncStatus ?? this.syncStatus,
      inputsGiven: inputsGiven,
      pobAmount: pobAmount,
      dayPlanId: dayPlanId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// A day's committed schedule (§16).
/// A day's intimation (§16): where the rep is working today, declared before
/// the day starts.
///
/// This is not a schedule and holds no visits — [activityIds] links any that
/// are later logged against it. It answers one question for the manager:
/// where are you today, and from what point did you say so. The captured
/// position and address are the evidence for the second half.
class DayPlan {
  const DayPlan({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.workType,
    this.areaId,
    this.areaName,
    this.clusterName,
    this.tourType = TourType.local,
    this.activityIds = const [],
    this.status = ApprovalStatus.draft,
    this.approvalHistory = const [],
    this.remarks,
    this.capturedPoint,
    this.capturedAddress,
    this.submittedAt,
  });

  final String id;
  final String employeeId;
  final DateTime date;
  final WorkType workType;
  final String? areaId;
  final String? areaName;
  final String? clusterName;
  final TourType tourType;
  final List<String> activityIds;
  final ApprovalStatus status;
  final List<ApprovalEvent> approvalHistory;
  final String? remarks;

  /// Where the rep was standing when they submitted, and the address that
  /// resolves to. Stored on the record rather than re-derived, because it is
  /// evidence of a moment.
  final GeoPoint? capturedPoint;
  final String? capturedAddress;
  final DateTime? submittedAt;
}

/// Aggregated view of a single day used by Home and the day-plan screen.
///
/// Derived from activities rather than stored, so it can never drift out of
/// sync with the underlying records (§66.9).
class DaySummary {
  const DaySummary({
    required this.date,
    required this.activities,
    this.workType = WorkType.fieldWork,
    this.headquarters = '',
    this.declaredAt,
  });

  final DateTime date;
  final List<Activity> activities;

  /// What the rep said they were doing today, from the day plan. Field work
  /// unless they declared otherwise.
  final WorkType workType;
  final String headquarters;

  /// When the day plan for this date was submitted, or null if the rep has
  /// not intimated yet.
  ///
  /// This is what makes the day "started" — not the clock. The pace line used
  /// to read the hour, so it said "Day not started" at 08:59 to a rep who had
  /// declared and driven out at seven, and "on track" at 09:01 to one who had
  /// done nothing at all. A day starts when the rep says it does.
  final DateTime? declaredAt;

  /// Whether the rep has intimated for this date.
  bool get isDeclared => declaredAt != null;

  int get planned => activities.length;
  int get completed =>
      activities.where((a) => a.status == ActivityStatus.completed).length;
  int get missed =>
      activities.where((a) => a.status == ActivityStatus.missed).length;
  int get remaining => activities.where((a) => a.status.isOpen).length;

  double get progress => planned == 0 ? 0 : completed / planned;
  int get progressPercent => (progress * 100).round();

  /// The next thing the rep should actually do — the single most important
  /// derived value in the product (§15).
  Activity? get nextAction {
    final open = activities.where((a) => a.status.isOpen).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return open.isEmpty ? null : open.first;
  }

  Activity? get inProgress {
    for (final a in activities) {
      if (a.status == ActivityStatus.inProgress) return a;
    }
    return null;
  }

  /// The one line under the bar: what state the day is in.
  ///
  /// Reads the declaration first and the clock second, in that order, because
  /// that is the order the facts matter in. Before the rep intimates there is
  /// nothing to pace against; once they have declared a non-field day, pace
  /// against a visit target is meaningless and the work type is the answer.
  String dayStatusLabel({DateTime? now}) {
    if (!isDeclared) return 'Day not started';
    if (workType != WorkType.fieldWork) {
      return 'Day started · ${workType.label}';
    }
    if (inProgress != null) return 'Visit in progress';
    return paceLabel(now: now);
  }

  /// Plain-language pace assessment shown under the progress bar. Compares
  /// completion against how much of the working day has elapsed, so "on track"
  /// means something at 11am as well as at 5pm.
  ///
  /// Only ever called on a declared field-work day — [dayStatusLabel] handles
  /// the rest — so it no longer second-guesses whether the day has begun.
  String paceLabel({DateTime? now}) {
    if (planned == 0) return 'No visits planned';
    if (completed == planned) return 'All visits complete';

    final reference = now ?? DateTime.now();
    const dayStart = 9;
    const dayEnd = 18;
    final hour = reference.hour + reference.minute / 60;

    // Declared before the working day opens: started, nothing due yet.
    if (hour < dayStart) return 'Day started · first visit ahead';

    final elapsed = ((hour - dayStart) / (dayEnd - dayStart)).clamp(0.0, 1.0);
    final expected = elapsed * planned;

    if (completed >= expected) return 'On track to meet your daily target';
    final behind = (expected - completed).ceil();
    return '$behind visit${behind == 1 ? '' : 's'} behind schedule';
  }
}
