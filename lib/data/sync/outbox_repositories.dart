/// Repository decorators that enqueue writes when the device is offline.
library;

import '../../core/location/geo_math.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';
import '../repositories/repositories.dart';
import 'outbox.dart';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _workTypeTerm = {
  WorkType.fieldWork: 'fieldWork',
  WorkType.officeWork: 'officeWork',
  WorkType.meeting: 'meeting',
  WorkType.training: 'training',
  WorkType.leave: 'leave',
  WorkType.holiday: 'holiday',
};

const _tourTypeTerm = {
  TourType.local: 'local',
  TourType.outstation: 'outstation',
  TourType.exStation: 'exStation',
};

const _geoTerm = {
  GeoVerification.verified: 'verified',
  GeoVerification.outOfRange: 'outOfRange',
  GeoVerification.unavailable: 'unavailable',
  GeoVerification.suspect: 'suspect',
};

const _categoryTerm = {
  ExpenseCategory.dailyAllowance: 'dailyAllowance',
  ExpenseCategory.travel: 'travel',
  ExpenseCategory.food: 'food',
  ExpenseCategory.lodging: 'lodging',
  ExpenseCategory.fuel: 'fuel',
  ExpenseCategory.other: 'other',
};

Map<String, dynamic> completeVisitPayload(Activity activity) {
  final geo = activity.geoResult;
  return {
    'p_activity_id': activity.id,
    'p_feedback': activity.feedback,
    'p_remarks': activity.remarks,
    'p_pop': activity.pop,
    'p_inputs_given': activity.inputsGiven,
    'p_pob_amount': activity.pobAmount,
    'p_rcpa_score': activity.rcpaScore,
    'p_expected_next_visit': activity.expectedNextVisit == null
        ? null
        : _isoDate(activity.expectedNextVisit!),
    'p_geo_verdict': geo == null
        ? 'unavailable'
        : _geoTerm[geo.verification] ?? 'unavailable',
    'p_geo_radius_m': geo?.radiusMeters,
    'p_geo_distance_m': geo?.distanceMeters,
    'p_geo_lat': geo?.captured?.latitude,
    'p_geo_lng': geo?.captured?.longitude,
    'p_out_of_range_reason': activity.outOfRangeReason,
    'p_rcpa_entries': [
      for (final e in activity.rcpaEntries)
        {
          'product_id': e.productId,
          'product_name': e.productName,
          'own_quantity': e.ownQuantity,
          'competitor_name': e.competitorName,
          'competitor_quantity': e.competitorQuantity,
        },
    ],
    'p_product_ids': activity.productIds,
    'p_photo_paths': activity.photoPaths,
  };
}

Map<String, dynamic> expenseUpsertPayload(Expense expense) => {
      'p_id': expense.id,
      'p_work_date': _isoDate(expense.date),
      'p_amount': expense.amount,
      'p_categories': expense.categories
          .map((c) => _categoryTerm[c] ?? 'other')
          .toList(),
      'p_description': expense.description,
      'p_remarks': expense.remarks,
      'p_travel_mode': expense.travelMode?.label,
      'p_destination': expense.place ?? expense.toLocation,
      'p_receipt_paths': expense.receiptPaths,
    };

Map<String, dynamic> dayPlanPayload(DayPlan plan) => {
      'p_id': plan.id,
      'p_work_date': _isoDate(plan.date),
      'p_work_type': _workTypeTerm[plan.workType],
      'p_area_id': plan.areaId,
      'p_cluster_id': null,
      'p_cluster_name': plan.clusterName,
      'p_tour_type': _tourTypeTerm[plan.tourType] ?? 'local',
      'p_remarks': plan.remarks,
      'p_captured_lat': plan.capturedPoint?.latitude,
      'p_captured_lng': plan.capturedPoint?.longitude,
      'p_captured_address': plan.capturedAddress,
    };

/// Wraps [ActivityRepository] so `completeVisit` can land in the outbox.
class OutboxActivityRepository implements ActivityRepository {
  OutboxActivityRepository({
    required this.inner,
    required this.store,
    required this.isOnline,
    this.onEnqueued,
  });

  final ActivityRepository inner;
  final OutboxStore store;
  final bool Function() isOnline;
  final void Function()? onEnqueued;

  @override
  Future<List<Activity>> list(
    Session session, {
    DateTime? date,
    DateTime? from,
    DateTime? to,
    ActivityStatus? status,
    String? employeeId,
    String? clientId,
  }) =>
      inner.list(
        session,
        date: date,
        from: from,
        to: to,
        status: status,
        employeeId: employeeId,
        clientId: clientId,
      );

  @override
  Future<Activity> byId(Session session, String id) =>
      inner.byId(session, id);

  @override
  Future<DaySummary> daySummary(String employeeId, DateTime date) =>
      inner.daySummary(employeeId, date);

  @override
  Future<Activity> create(Activity activity) => inner.create(activity);

  @override
  Future<Activity> update(Session session, Activity activity) =>
      inner.update(session, activity);

  @override
  Future<Activity> startVisit(String activityId) =>
      inner.startVisit(activityId);

  @override
  Future<Activity> completeVisit(Activity activity) async {
    if (!isOnline()) {
      await store.enqueue(
        kind: OutboxKind.completeVisit,
        payload: completeVisitPayload(activity),
        label: 'Visit — ${activity.clientName}',
      );
      onEnqueued?.call();
      return activity.copyWith(syncStatus: SyncStatus.savedLocally);
    }
    return inner.completeVisit(activity);
  }

  @override
  Future<String> uploadVisitPhoto({
    required List<int> bytes,
    required String mimeType,
    String fileName = 'photo.jpg',
  }) =>
      inner.uploadVisitPhoto(
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
}

class OutboxDayPlanRepository implements DayPlanRepository {
  OutboxDayPlanRepository({
    required this.inner,
    required this.store,
    required this.isOnline,
    this.onEnqueued,
  });

  final DayPlanRepository inner;
  final OutboxStore store;
  final bool Function() isOnline;
  final void Function()? onEnqueued;

  @override
  Future<DayPlan?> forDate(String employeeId, DateTime date) =>
      inner.forDate(employeeId, date);

  @override
  Future<List<DayPlan>> list(Session session, {String? employeeId}) =>
      inner.list(session, employeeId: employeeId);

  @override
  Future<String> addressFor(GeoPoint point, {String? areaId}) =>
      inner.addressFor(point, areaId: areaId);

  @override
  Future<DayPlan> submit(DayPlan plan) async {
    if (!isOnline()) {
      await store.enqueue(
        kind: OutboxKind.submitDayPlan,
        payload: dayPlanPayload(plan),
        label: 'Day plan — ${_isoDate(plan.date)}',
      );
      onEnqueued?.call();
      return DayPlan(
        id: plan.id,
        employeeId: plan.employeeId,
        date: plan.date,
        workType: plan.workType,
        areaId: plan.areaId,
        areaName: plan.areaName,
        clusterName: plan.clusterName,
        tourType: plan.tourType,
        activityIds: plan.activityIds,
        status: ApprovalStatus.submitted,
        approvalHistory: plan.approvalHistory,
        remarks: plan.remarks,
        capturedPoint: plan.capturedPoint,
        capturedAddress: plan.capturedAddress,
        submittedAt: DateTime.now(),
      );
    }
    return inner.submit(plan);
  }
}

class OutboxExpenseRepository implements ExpenseRepository {
  OutboxExpenseRepository({
    required this.inner,
    required this.store,
    required this.isOnline,
    this.onEnqueued,
  });

  final ExpenseRepository inner;
  final OutboxStore store;
  final bool Function() isOnline;
  final void Function()? onEnqueued;

  @override
  Future<List<Expense>> list(
    Session session, {
    ApprovalStatus? status,
    String? employeeId,
  }) =>
      inner.list(session, status: status, employeeId: employeeId);

  @override
  Future<Expense> byId(Session session, String id) =>
      inner.byId(session, id);

  @override
  Future<double> dailyAllowance() => inner.dailyAllowance();

  @override
  Future<List<ClaimDay>> claimMonth(Session session, DateTime month,
          {String? employeeId}) =>
      inner.claimMonth(session, month, employeeId: employeeId);

  @override
  Future<int> confirmStandardDays(Session session, List<ClaimDay> days) =>
      inner.confirmStandardDays(session, days);

  @override
  Future<int> submitMonth(Session session, DateTime month) =>
      inner.submitMonth(session, month);

  @override
  Future<String> uploadReceipt({
    required List<int> bytes,
    required String mimeType,
    String fileName = 'receipt.jpg',
  }) =>
      inner.uploadReceipt(
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

  @override
  Future<Expense> create(Expense expense) async {
    if (!isOnline()) {
      await store.enqueue(
        kind: OutboxKind.createOrUpdateExpense,
        payload: expenseUpsertPayload(expense),
        label: 'Expense — ${expense.category.label}',
      );
      onEnqueued?.call();
      return expense.copyWith(syncStatus: SyncStatus.savedLocally);
    }
    return inner.create(expense);
  }

  @override
  Future<Expense> update(Session session, Expense expense) async {
    if (!isOnline()) {
      await store.enqueue(
        kind: OutboxKind.createOrUpdateExpense,
        payload: expenseUpsertPayload(expense),
        label: 'Expense — ${expense.category.label}',
      );
      onEnqueued?.call();
      return expense.copyWith(syncStatus: SyncStatus.savedLocally);
    }
    return inner.update(session, expense);
  }

  @override
  Future<Expense> submit(String id) async {
    if (!isOnline()) {
      await store.enqueue(
        kind: OutboxKind.submitExpense,
        payload: {'p_id': id},
        label: 'Expense submit',
      );
      onEnqueued?.call();
      // Best-effort local shape: caller usually already has the expense.
      return Expense(
        id: id,
        employeeId: '',
        employeeName: '',
        date: DateTime.now(),
        amount: 0,
        status: ApprovalStatus.pending,
        syncStatus: SyncStatus.savedLocally,
      );
    }
    return inner.submit(id);
  }
}
