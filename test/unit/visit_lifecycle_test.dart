import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';

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
}
