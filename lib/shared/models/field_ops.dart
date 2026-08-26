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

  bool get hasReceipt => receiptPaths.isNotEmpty;

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
    );
  }
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
