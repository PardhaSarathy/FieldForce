import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/shared/models/organization.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/field_ops.dart';

/// Drafts can be corrected, and correcting one must not fork the record.
///
/// `TravelRepository` had no `update` at all and `ExpenseRepository.update`
/// was unreachable, so the Edit button on a draft did nothing. The risk when
/// wiring these is the opposite failure: saving an edit as a *new* record,
/// which leaves the original behind and doubles the claim.
void main() {
  test('editing a travel plan rewrites it in place', () async {
    final repo = MockTravelRepository();
    final before = MockStore.instance.travelPlans.length;
    final plan = MockStore.instance.travelPlans.first;

    // Rebuilt from the constructor, exactly as the form does — `TravelPlan`'s
    // copyWith is deliberately narrow (status, history, sync) because the form
    // owns every other field.
    final edited = TravelPlan(
      id: plan.id,
      employeeId: plan.employeeId,
      employeeName: plan.employeeName,
      date: plan.date,
      workType: plan.workType,
      status: plan.status,
      areaId: plan.areaId,
      areaName: plan.areaName,
      territoryName: plan.territoryName,
      plannedVisits: plan.plannedVisits,
      clientNames: plan.clientNames,
      remarks: 'Route changed — clinic moved',
      approvalHistory: plan.approvalHistory,
      createdAt: plan.createdAt,
    );
    final saved = await repo.update(_asOwner(plan.employeeId), edited);

    expect(saved.id, plan.id, reason: 'an edit keeps the id');
    expect(MockStore.instance.travelPlans.length, before,
        reason: 'an edit must not create a second plan');
    expect(
      MockStore.instance.travelPlans.firstWhere((p) => p.id == plan.id).remarks,
      'Route changed — clinic moved',
    );
  });

  test('editing an expense rewrites it in place', () async {
    final repo = MockExpenseRepository();
    final before = MockStore.instance.expenses.length;
    final expense = MockStore.instance.expenses
        .firstWhere((e) => e.status == ApprovalStatus.draft);

    final saved = await repo.update(
      _asOwner(expense.employeeId),
      expense.copyWith(amount: 1234),
    );

    expect(saved.id, expense.id);
    expect(MockStore.instance.expenses.length, before,
        reason: 'an edit must not create a second claim');
    expect(
      MockStore.instance.expenses.firstWhere((e) => e.id == expense.id).amount,
      1234,
    );
  });

  test('an edit carries the approval history with it', () async {
    // The history is append-only and belongs to the record. Rebuilding the
    // object from the form fields would drop it silently.
    final repo = MockExpenseRepository();
    final withHistory = MockStore.instance.expenses
        .firstWhere((e) => e.approvalHistory.isNotEmpty);

    final saved = await repo.update(
      _asOwner(withHistory.employeeId),
      withHistory.copyWith(remarks: 'edited'),
    );
    expect(saved.approvalHistory, isNotEmpty);
  });

  test('correcting an activity does not inflate the client history', () async {
    // The reason a correction goes through `update` and not `completeVisit`:
    // completion also bumps the client's visit count and last-seen date, so
    // re-running it on an edit would credit a second visit for a typo fix.
    final activities = MockActivityRepository();
    final logged = MockStore.instance.activities
        .firstWhere((a) => a.status == ActivityStatus.completed);
    final client = MockStore.instance.clients
        .firstWhere((c) => c.id == logged.clientId);
    final visitsBefore = client.totalVisits;

    await activities.update(
      _asOwner(logged.employeeId),
      logged.copyWith(feedback: 'corrected note'),
    );

    final after = MockStore.instance.clients
        .firstWhere((c) => c.id == logged.clientId);
    expect(after.totalVisits, visitsBefore,
        reason: 'a correction is not another visit');
    expect(
      MockStore.instance.activities
          .firstWhere((a) => a.id == logged.id)
          .feedback,
      'corrected note',
    );
  });
}

/// A session for whoever owns the record.
///
/// `update` is owner-only now — a manager may see a rep's claim and must not
/// rewrite it — so a test correcting a record has to be the person who filed
/// it, which is what actually happens in the app.
Session _asOwner(String employeeId) => Session(
      employee: MockStore.instance.seed.employees
          .firstWhere((e) => e.id == employeeId),
      loginAt: DateTime(2026, 9),
    );
