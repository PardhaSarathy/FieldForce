import '../enums/app_enums.dart';
import 'activity.dart';

/// A planned day of travel awaiting manager approval (§21).
class TravelPlan {
  const TravelPlan({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.workType,
    required this.status,
    this.areaId,
    this.areaName,
    this.territoryName,
    this.tourType = TourType.local,
    this.travelMode = TravelMode.bike,
    this.destination,
    this.purpose,
    this.plannedVisits = 0,
    this.estimatedKm,
    this.clientNames = const [],
    this.remarks,
    this.approvalHistory = const [],
    this.syncStatus = SyncStatus.synced,
    this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final WorkType workType;
  final ApprovalStatus status;
  final String? areaId;
  final String? areaName;
  final String? territoryName;
  final TourType tourType;
  final TravelMode travelMode;
  final String? destination;
  final String? purpose;
  final int plannedVisits;
  final double? estimatedKm;

  /// The clients the rep intends to call on. Names rather than ids so a plan
  /// stays readable if a client is later renamed or deactivated — the plan is
  /// a record of intent at a moment, not a live query.
  final List<String> clientNames;

  final String? remarks;
  final List<ApprovalEvent> approvalHistory;
  final SyncStatus syncStatus;
  final DateTime? createdAt;

  TravelPlan copyWith({
    ApprovalStatus? status,
    List<ApprovalEvent>? approvalHistory,
    SyncStatus? syncStatus,
  }) {
    return TravelPlan(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      workType: workType,
      status: status ?? this.status,
      areaId: areaId,
      areaName: areaName,
      territoryName: territoryName,
      tourType: tourType,
      travelMode: travelMode,
      destination: destination,
      purpose: purpose,
      plannedVisits: plannedVisits,
      clientNames: clientNames,
      remarks: remarks,
      estimatedKm: estimatedKm,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
    );
  }
}

/// A reimbursement claim (§22).
class Expense {
  const Expense({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.category,
    required this.amount,
    required this.status,
    this.description,
    this.remarks,
    this.receiptPaths = const [],
    this.approvalHistory = const [],
    this.syncStatus = SyncStatus.synced,
    this.travelMode,
    this.fromLocation,
    this.toLocation,
    this.distanceKm,
    this.createdAt,
    this.dayPlanId,
    this.allowance = 0,
    this.scope = ClaimScope.local,
    this.place,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final ExpenseCategory category;
  final double amount;
  final ApprovalStatus status;
  final String? description;
  final String? remarks;
  final List<String> receiptPaths;
  final List<ApprovalEvent> approvalHistory;
  final SyncStatus syncStatus;

  // Travel-specific detail, populated only for the travel category.
  final TravelMode? travelMode;
  final String? fromLocation;
  final String? toLocation;
  final double? distanceKm;

  final DateTime? createdAt;

  /// The day's intimation this claim hangs off (§16).
  ///
  /// A rep can only claim for a day he declared and worked. Enforced at the
  /// repository rather than in a screen, so there is one answer to "can this
  /// be claimed" no matter which screen asks.
  final String? dayPlanId;

  /// What the day was worth when the claim was made.
  ///
  /// Stored on the record, not looked up. The rate is company reference data
  /// and will change; a claim settled at ₹250 must still read ₹250 next year,
  /// and a report that recomputes history against today's figure is a report
  /// that disagrees with what was actually paid.
  final double allowance;

  /// Where the day happened. Context for the excess, never a rate.
  final ClaimScope scope;

  /// The place travelled to, when [scope] is out of territory.
  final String? place;

  bool get hasReceipt => receiptPaths.isNotEmpty;

  /// Spent above the day's allowance. This is the part that needs a bill.
  double get excess {
    final over = amount - allowance;
    return over > 0 ? over : 0;
  }

  /// A claim for exactly the allowance — the one-tap case, which needs no
  /// bill and no explanation.
  bool get isStandard => excess == 0;

  Expense copyWith({
    ApprovalStatus? status,
    List<ApprovalEvent>? approvalHistory,
    SyncStatus? syncStatus,
    double? amount,
    String? description,
    String? remarks,
    List<String>? receiptPaths,
  }) {
    return Expense(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      category: category,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      description: description ?? this.description,
      remarks: remarks ?? this.remarks,
      receiptPaths: receiptPaths ?? this.receiptPaths,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      syncStatus: syncStatus ?? this.syncStatus,
      travelMode: travelMode,
      fromLocation: fromLocation,
      toLocation: toLocation,
      distanceKm: distanceKm,
      createdAt: createdAt,
      dayPlanId: dayPlanId,
      allowance: allowance,
      scope: scope,
      place: place,
    );
  }
}

/// A day the rep declared, and what has been claimed against it.
///
/// **Derived, never stored.** It is a day plan joined to whatever expenses
/// were filed for that date, exactly as a report is derived from the records
/// beneath it — storing it would give the app two places to disagree about
/// whether a day is claimed.
class ClaimDay {
  const ClaimDay({
    required this.date,
    required this.dayPlanId,
    required this.workType,
    required this.place,
    required this.allowance,
    this.expenses = const [],
    this.calls = 0,
  });

  final DateTime date;
  final String dayPlanId;
  final WorkType workType;

  /// Where the day was worked — the day plan's area, or its cluster.
  final String place;

  /// What this day is worth, before anything is spent above it.
  final double allowance;

  final List<Expense> expenses;

  /// Visits completed that day. Context on the row, and the thing that makes
  /// an unclaimed day obviously a real working day rather than a blank.
  final int calls;

  /// Leave and holidays are not worked, so nothing can be claimed against
  /// them.
  ///
  /// Every other declared type is claimable. Whether a Meeting or Training
  /// day should earn the full allowance is a company policy question still
  /// with the client — when they answer, this getter is the only edit.
  static bool isClaimable(WorkType type) =>
      type != WorkType.leave && type != WorkType.holiday;

  bool get claimable => isClaimable(workType);

  double get claimed => expenses.fold(0, (sum, e) => sum + e.amount);

  bool get hasClaim => expenses.isNotEmpty;

  /// Claimed above the allowance — the part carrying bills.
  bool get isExcess => claimed > allowance;

  /// What is left of the day's allowance.
  ///
  /// The form measures a new line against **this**, not against the full
  /// allowance. Measured against the full figure, a rep could file ₹250 twice
  /// on one day — each line at the allowance, each needing no bill — and walk
  /// away with ₹500 against a ₹250 day. The rule is per day, so the check has
  /// to be per day.
  double get remainingAllowance {
    final left = allowance - claimed;
    return left > 0 ? left : 0;
  }

  /// The state to show for the day, when several claims sit on it.
  ///
  /// The worst news wins: a rejected line is the one the rep has to act on,
  /// and a day that is half approved and half rejected is not "approved".
  ApprovalStatus? get status {
    if (expenses.isEmpty) return null;
    for (final s in [
      ApprovalStatus.rejected,
      ApprovalStatus.draft,
      ApprovalStatus.submitted,
      ApprovalStatus.pending,
    ]) {
      if (expenses.any((e) => e.status == s)) return s;
    }
    return ApprovalStatus.approved;
  }

  int get receiptCount =>
      expenses.fold(0, (sum, e) => sum + e.receiptPaths.length);

  /// A worked day with nothing filed against it yet. The figure that drives
  /// the whole screen.
  bool get isOpen => claimable && !hasClaim;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.workType,
    this.note,
  });

  final DateTime date;
  final AttendanceStatus status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final WorkType? workType;
  final String? note;
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.type,
    required this.reason,
    required this.status,
    this.approvalHistory = const [],
    this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime fromDate;
  final DateTime toDate;
  final LeaveType type;
  final String reason;
  final ApprovalStatus status;
  final List<ApprovalEvent> approvalHistory;
  final DateTime? createdAt;

  /// Inclusive day count.
  int get days => toDate.difference(fromDate).inDays + 1;

  LeaveRequest copyWith({
    ApprovalStatus? status,
    List<ApprovalEvent>? approvalHistory,
  }) {
    return LeaveRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
      reason: reason,
      status: status ?? this.status,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      createdAt: createdAt,
    );
  }
}

class Holiday {
  const Holiday({
    required this.id,
    required this.name,
    required this.date,
    this.isOptional = false,
  });

  final String id;
  final String name;
  final DateTime date;
  final bool isOptional;
}

class Payslip {
  const Payslip({
    required this.id,
    required this.month,
    required this.grossPay,
    required this.deductions,
    this.earnings = const {},
    this.deductionBreakup = const {},
  });

  final String id;
  final DateTime month;
  final double grossPay;
  final double deductions;
  final Map<String, double> earnings;
  final Map<String, double> deductionBreakup;

  double get netPay => grossPay - deductions;
}

class AppDocument {
  const AppDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.uploadedAt,
    this.sizeLabel,
    this.category = 'General',
    this.url,
  });

  final String id;
  final String name;
  final String type;
  final DateTime uploadedAt;
  final String? sizeLabel;
  final String category;
  final String? url;
}

/// Marketing and training material available to the field (§26).
class Resource {
  const Resource({
    required this.id,
    required this.title,
    required this.category,
    required this.updatedAt,
    this.description,
    this.fileType = 'PDF',
    this.sizeLabel,
    this.productId,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String category;
  final DateTime updatedAt;
  final String? description;
  final String fileType;
  final String? sizeLabel;
  final String? productId;
  final String? thumbnailUrl;
}
