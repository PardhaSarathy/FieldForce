import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_report_repository.dart';
import '../../data/repositories/mock_repositories.dart';
import '../../data/repositories/api_repositories.dart';
import '../../data/remote/backend.dart';
import '../../data/repositories/repositories.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/engagement.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';

/// Composition root.
///
/// Every repository is exposed as a provider bound to its mock implementation.
/// Swapping to the real API is a one-line change per provider — no screen or
/// controller is aware of which implementation it is talking to (§7).

// The whole cost of adding a backend, as promised: two lines choose an
// implementation and no screen knows the difference. Only these two have a
// live version — employees, reporting lines and leave are what the database
// holds — and the rest stay on the seed until their tables land.
final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => isLive ? ApiAuthRepository() : MockAuthRepository());
final employeeRepositoryProvider =
    Provider<EmployeeRepository>((ref) => MockEmployeeRepository());
final clientRepositoryProvider =
    Provider<ClientRepository>((ref) => MockClientRepository());
final activityRepositoryProvider =
    Provider<ActivityRepository>((ref) => MockActivityRepository());
final dayPlanRepositoryProvider =
    Provider<DayPlanRepository>((ref) => MockDayPlanRepository());
final travelRepositoryProvider =
    Provider<TravelRepository>((ref) => MockTravelRepository());
final expenseRepositoryProvider =
    Provider<ExpenseRepository>((ref) => MockExpenseRepository());
final hrRepositoryProvider = Provider<HrRepository>(
    (ref) => isLive ? ApiHrRepository() : MockHrRepository());
final exportRepositoryProvider =
    Provider<ExportRepository>((ref) => MockExportRepository());
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

  /// Ask for a code. Stays unauthenticated — the screen moves to its second
  /// step on its own, because a failure here is about the address and belongs
  /// beside the field the address was typed into.
  Future<void> requestSignInCode(String email) async {
    await _repo.requestSignInCode(email);
  }

  Future<void> signInWithCode(String email, String code) async {
    state = const AuthAuthenticating();
    try {
      state = AuthAuthenticated(
        await _repo.signInWithCode(email: email, code: code),
      );
    } on AuthException catch (e) {
      state = AuthFailure(e.message);
    } catch (_) {
      state = const AuthFailure('We could not sign you in. Please try again.');
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
  // Home's day state comes from the day plan, so submitting one has to move
  // this screen. Without the revision watch the rep intimated, came back, and
  // Home still said "Day not started".
  ref.watch(dataRevisionProvider);
  return repo.daySummary(session.employee.id, DateTime.now());
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

/// The month the tour plan screen is showing.
///
/// Defaults to **next** month, because that is the one being planned. A rep
/// files next month's tour during this one; opening on the current month would
/// land them on a plan already with their manager.
final tourMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month + 1);
});

/// The chosen month as a day-by-day tour plan.
final tourMonthPlanProvider =
    FutureProvider.autoDispose<TourMonth>((ref) async {
  final session = ref.watch(sessionProvider);
  final month = ref.watch(tourMonthProvider);
  ref.watch(dataRevisionProvider);

  return ref.watch(travelRepositoryProvider).month(session, month);
});

/// The month the expense claim screen is showing. Not auto-disposed: stepping
/// into a day and back should return to the month you were in, not to today.
final claimMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// What one worked day pays. Company reference data (§ master data), so it is
/// read through the repository rather than written into a screen.
final dailyAllowanceProvider = FutureProvider<double>(
  (ref) => ref.watch(expenseRepositoryProvider).dailyAllowance(),
);

/// The chosen month as claimable days: every date the rep intimated, joined
/// to whatever has been filed against it.
final claimMonthDaysProvider =
    FutureProvider.autoDispose<List<ClaimDay>>((ref) async {
  final session = ref.watch(sessionProvider);
  final month = ref.watch(claimMonthProvider);
  ref.watch(dataRevisionProvider);

  return ref.watch(expenseRepositoryProvider).claimMonth(session, month);
});

/// Bumped after any write so dependent lists refetch. A crude but honest
/// invalidation signal for the mock build; the real app will use targeted
/// cache invalidation per repository.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

extension DataRefresh on WidgetRef {
  void bumpRevision() =>
      read(dataRevisionProvider.notifier).update((value) => value + 1);
}
