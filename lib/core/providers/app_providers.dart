import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_report_repository.dart';
import '../../data/repositories/mock_repositories.dart';
import '../../data/repositories/repositories.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/engagement.dart';
import '../../shared/models/organization.dart';

/// Composition root.
///
/// Every repository is exposed as a provider bound to its mock implementation.
/// Swapping to the real API is a one-line change per provider — no screen or
/// controller is aware of which implementation it is talking to (§7).

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => MockAuthRepository());
final employeeRepositoryProvider =
    Provider<EmployeeRepository>((ref) => MockEmployeeRepository());
final clientRepositoryProvider =
    Provider<ClientRepository>((ref) => MockClientRepository());
final activityRepositoryProvider =
    Provider<ActivityRepository>((ref) => MockActivityRepository());
final travelRepositoryProvider =
    Provider<TravelRepository>((ref) => MockTravelRepository());
final expenseRepositoryProvider =
    Provider<ExpenseRepository>((ref) => MockExpenseRepository());
final hrRepositoryProvider = Provider<HrRepository>((ref) => MockHrRepository());
final businessRepositoryProvider =
    Provider<BusinessRepository>((ref) => MockBusinessRepository());
final approvalRepositoryProvider =
    Provider<ApprovalRepository>((ref) => MockApprovalRepository());
final taskRepositoryProvider =
    Provider<TaskRepository>((ref) => MockTaskRepository());
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => MockNotificationRepository());
final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => MockChatRepository());
final resourceRepositoryProvider =
    Provider<ResourceRepository>((ref) => MockResourceRepository());
final surveyRepositoryProvider =
    Provider<SurveyRepository>((ref) => MockSurveyRepository());
final complaintRepositoryProvider =
    Provider<ComplaintRepository>((ref) => MockComplaintRepository());
final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => MockReportRepository());

// ================================================================ session ==

/// Explicit authentication state (§6) — no scattered booleans.
sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});

  /// Set when the user was signed out involuntarily, so the login screen can
  /// explain why rather than appearing for no reason.
  final String? message;
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);
  final Session session;
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthUnauthenticated();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> login(String employeeCode, String password) async {
    state = const AuthAuthenticating();
    try {
      final session = await _repo.login(
        employeeCode: employeeCode,
        password: password,
      );
      state = AuthAuthenticated(session);
    } on AuthException catch (e) {
      state = AuthFailure(e.message);
    } catch (_) {
      state = const AuthFailure(
        'We could not sign you in. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  /// Called when a protected call is refused by the server.
  void expireSession() {
    state = const AuthUnauthenticated(
      message: 'Your session expired. Please sign in again.',
    );
  }

  void clearError() {
    if (state is AuthFailure) state = const AuthUnauthenticated();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in session. Throws if read outside an authenticated route —
/// which is correct: every guarded screen is unreachable without one.
final sessionProvider = Provider<Session>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthAuthenticated) return state.session;
  throw StateError('sessionProvider read while unauthenticated');
});

final currentEmployeeProvider =
    Provider<Employee>((ref) => ref.watch(sessionProvider).employee);

// ============================================================== app state ==

/// Simulated connectivity, so offline treatments can be exercised in the demo
/// build. The real implementation listens to platform connectivity.
class ConnectivityController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setOnline(bool value) => state = value;
}

final isOnlineProvider =
    NotifierProvider<ConnectivityController, bool>(ConnectivityController.new);

/// Count of records saved locally and awaiting sync (§61).
final pendingSyncCountProvider = Provider<int>((ref) {
  // Wired to the outbox once the sync layer lands; zero while online-only.
  return ref.watch(isOnlineProvider) ? 0 : 2;
});

/// Geo-fence policy. Admin-configurable (§130); defaults to `warn` so a rep is
/// never blocked from recording work they genuinely did.
final geoFencePolicyProvider = StateProvider<GeoFencePolicy>(
  (ref) => GeoFencePolicy.warn,
);

final geoFenceRadiusProvider = StateProvider<double>((ref) => 50);

// ============================================================== data reads ==

/// Today's plan for the signed-in user — the single source for Home.
final todaySummaryProvider = FutureProvider.autoDispose<DaySummary>((ref) async {
  final session = ref.watch(sessionProvider);
  final repo = ref.watch(activityRepositoryProvider);
  return repo.daySummary(session.employee.id, DateTime.now());
});

/// Day summary for an arbitrary date, used by the day-plan and calendar views.
final daySummaryProvider =
    FutureProvider.autoDispose.family<DaySummary, DateTime>((ref, date) async {
  final session = ref.watch(sessionProvider);
  final repo = ref.watch(activityRepositoryProvider);
  return repo.daySummary(session.employee.id, date);
});

final unreadNotificationsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

final notificationsProvider =
    FutureProvider.autoDispose.family<List<AppNotification>, bool>(
  (ref, unreadOnly) =>
      ref.watch(notificationRepositoryProvider).list(unreadOnly: unreadOnly),
);

final pendingApprovalsProvider =
    FutureProvider.autoDispose<List<ApprovalItem>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isManager) return const [];
  return ref.watch(approvalRepositoryProvider).pending(session);
});

final managerDashboardProvider =
    FutureProvider.autoDispose<ManagerDashboard>((ref) async {
  final session = ref.watch(sessionProvider);
  return ref.watch(reportRepositoryProvider).managerDashboard(session);
});

final teamProvider = FutureProvider.autoDispose<List<Employee>>((ref) async {
  final session = ref.watch(sessionProvider);
  return ref.watch(employeeRepositoryProvider).teamOf(session);
});

final myTasksProvider = FutureProvider.autoDispose<List<FieldTask>>((ref) async {
  final session = ref.watch(sessionProvider);
  return ref
      .watch(taskRepositoryProvider)
      .list(session, employeeId: session.employee.id);
});

/// Open (not completed) tasks for the signed-in user — the "Pending Tasks"
/// figure on Home.
final pendingTaskCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final tasks = await ref.watch(myTasksProvider.future);
  return tasks.where((t) => t.effectiveStatus() != TaskStatus.completed).length;
});

/// This month's visit target for the signed-in user, used as the secondary
/// figure under Home's goal ring. Null when no target has been assigned.
final monthlyVisitTargetProvider =
    FutureProvider.autoDispose<Target?>((ref) async {
  final session = ref.watch(sessionProvider);
  ref.watch(dataRevisionProvider);

  final targets = await ref.watch(businessRepositoryProvider).targets(
        session,
        employeeId: session.employee.id,
        month: DateTime.now(),
      );
  return targets.isEmpty ? null : targets.first;
});

/// Bumped after any write so dependent lists refetch. A crude but honest
/// invalidation signal for the mock build; the real app will use targeted
/// cache invalidation per repository.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

extension DataRefresh on WidgetRef {
  void bumpRevision() =>
      read(dataRevisionProvider.notifier).update((value) => value + 1);
}
