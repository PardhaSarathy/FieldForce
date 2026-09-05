import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/activity.dart';
import 'package:pharmaconnect/shared/widgets/primitives.dart';

/// A visit's start time must be stamped when it starts.
///
/// `startVisit` existed on the repository for the entire build and nothing
/// called it. Completion fell back to `actualStart ?? DateTime.now()`, so every
/// visit's start was recorded as the moment it *ended*: activity detail showed
/// a start equal to the end, and any duration computed from the pair was zero.
void main() {
  test('startVisit stamps the start and moves the activity in-progress',
      () async {
    final repo = MockActivityRepository();
    final open = MockStore.instance.activities
        .firstWhere((a) => a.status == ActivityStatus.planned);

    expect(open.actualStart, isNull);

    final started = await repo.startVisit(open.id);

    expect(started.status, ActivityStatus.inProgress);
    expect(started.actualStart, isNotNull);
  });

  test('completing after starting keeps the original start', () async {
    final repo = MockActivityRepository();
    final open = MockStore.instance.activities
        .where((a) => a.status == ActivityStatus.planned)
        .elementAt(1);

    final started = await repo.startVisit(open.id);
    final startedAt = started.actualStart!;

    // A visit takes time. Completion must not overwrite the stamp with "now".
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final completed = await repo.completeVisit(
      started.copyWith(status: ActivityStatus.completed),
    );

    expect(completed.actualStart, startedAt,
        reason: 'the start time is when the rep arrived, not when they left');
    expect(completed.actualEnd, isNotNull);
    expect(completed.actualEnd!.isBefore(completed.actualStart!), isFalse);
  });

  group('planned and unplanned is an origin, not a status', () {
    Activity call({required bool unplanned}) => Activity(
          id: 'a-$unplanned',
          employeeId: 'e1',
          employeeName: 'Rep',
          clientId: 'c1',
          clientName: 'Dr A',
          scheduledStart: DateTime(2026, 9, 5, 12),
          status: ActivityStatus.upcoming,
          isUnplanned: unplanned,
        );

    test('completing a call does not erase where it came from', () {
      // Folded into ActivityStatus, "unplanned" would survive exactly until
      // the visit was made — which is when a manager starts asking about it.
      final added = call(unplanned: true);
      expect(added.isUnplanned, isTrue);
      expect(
        added.copyWith(status: ActivityStatus.completed).isUnplanned,
        isTrue,
        reason: 'an unplanned call that happened is still an unplanned call',
      );
      expect(call(unplanned: false).isUnplanned, isFalse);
    });

    test('the badge reads the origin before the call and the outcome after',
        () {
      // One badge either way. A card carrying both squeezes the pair until
      // one of them ellipsises, which a client row already taught this app.
      expect(
        StatusBadge.activity(ActivityStatus.upcoming, isUnplanned: true).label,
        'Unplanned',
      );
      expect(
        StatusBadge.activity(ActivityStatus.completed, isUnplanned: true).label,
        'Completed',
      );
      // "Upcoming" is gone from the surface. Every open call is upcoming, so
      // the word separated nothing from anything; the status stays underneath
      // because it is how the day's next call is found.
      expect(
        StatusBadge.activity(ActivityStatus.upcoming).label,
        'Planned',
      );
      expect(
        StatusBadge.activity(ActivityStatus.inProgress).label,
        'In Progress',
        reason: 'a call being made now is neither an origin nor an outcome',
      );
    });
  });
}
