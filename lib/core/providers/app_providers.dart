import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_report_repository.dart';
import '../../data/repositories/mock_repositories.dart';
import '../../data/repositories/api_repositories.dart';
import '../../data/remote/backend.dart';
import '../../data/repositories/repositories.dart';
import '../../data/sync/outbox.dart';
import '../../data/sync/outbox_repositories.dart';
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
// implementation and no screen knows the difference. Live mode flips every
// product repository once its tables and RPCs exist; fixture mode stays on
// mocks without env / dart-defines.
final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => isLive ? ApiAuthRepository() : MockAuthRepository());
final employeeRepositoryProvider = Provider<EmployeeRepository>(
    (ref) => isLive ? ApiEmployeeRepository() : MockEmployeeRepository());
final clientRepositoryProvider = Provider<ClientRepository>(
    (ref) => isLive ? ApiClientRepository() : MockClientRepository());

final outboxStoreProvider = Provider<OutboxStore>((ref) => OutboxStore());

final outboxFlusherProvider = Provider<OutboxFlusher>(
  (ref) => OutboxFlusher(ref.watch(outboxStoreProvider)),
);

final outboxRevisionProvider = StateProvider<int>((ref) => 0);

void _bumpOutbox(Ref ref) {
  ref.read(outboxRevisionProvider.notifier).state++;
}

final outboxItemsProvider =
    FutureProvider.autoDispose<List<OutboxItem>>((ref) async {
  ref.watch(outboxRevisionProvider);
  return ref.read(outboxStoreProvider).list();
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  if (!isLive) return MockActivityRepository();
  return OutboxActivityRepository(
    inner: ApiActivityRepository(),
    store: ref.watch(outboxStoreProvider),
    isOnline: () => ref.read(isOnlineProvider),
    onEnqueued: () => _bumpOutbox(ref),
  );
});
final dayPlanRepositoryProvider = Provider<DayPlanRepository>((ref) {
  if (!isLive) return MockDayPlanRepository();
  return OutboxDayPlanRepository(
    inner: ApiDayPlanRepository(),
    store: ref.watch(outboxStoreProvider),
    isOnline: () => ref.read(isOnlineProvider),
    onEnqueued: () => _bumpOutbox(ref),
  );
});
final travelRepositoryProvider = Provider<TravelRepository>(
    (ref) => isLive ? ApiTravelRepository() : MockTravelRepository());
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  if (!isLive) return MockExpenseRepository();
  return OutboxExpenseRepository(
    inner: ApiExpenseRepository(),
    store: ref.watch(outboxStoreProvider),
    isOnline: () => ref.read(isOnlineProvider),
    onEnqueued: () => _bumpOutbox(ref),
  );
});
final hrRepositoryProvider = Provider<HrRepository>(
    (ref) => isLive ? ApiHrRepository() : MockHrRepository());
final exportRepositoryProvider =
    Provider<ExportRepository>(
        (ref) => isLive ? ApiExportRepository() : MockExportRepository());
final businessRepositoryProvider = Provider<BusinessRepository>(
    (ref) => isLive ? ApiBusinessRepository() : MockBusinessRepository());
final approvalRepositoryProvider = Provider<ApprovalRepository>(
    (ref) => isLive ? ApiApprovalRepository() : MockApprovalRepository());
final taskRepositoryProvider = Provider<TaskRepository>(
    (ref) => isLive ? ApiTaskRepository() : MockTaskRepository());
final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => isLive ? ApiNotificationRepository() : MockNotificationRepository());
final chatRepositoryProvider = Provider<ChatRepository>(
    (ref) => isLive ? ApiChatRepository() : MockChatRepository());
final resourceRepositoryProvider = Provider<ResourceRepository>(
    (ref) => isLive ? ApiResourceRepository() : MockResourceRepository());
final surveyRepositoryProvider = Provider<SurveyRepository>(
    (ref) => isLive ? ApiSurveyRepository() : MockSurveyRepository());
final complaintRepositoryProvider = Provider<ComplaintRepository>(
    (ref) => isLive ? ApiComplaintRepository() : MockComplaintRepository());
final reportRepositoryProvider = Provider<ReportRepository>(
    (ref) => isLive ? ApiReportRepository() : MockReportRepository());

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
  /// Starts *unknown*, not unauthenticated.
  ///
  /// Those are different claims and the difference is a whole screen: the app
  /// opened with "nobody is signed in" and sent everybody to the login form,
  /// including the person who signed in yesterday and whose session Supabase
  /// had refreshed and was holding all along. The router shows the splash
  /// while this is unknown, so nobody is asked to sign in twice.
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Ask the client what it already has, rather than keeping a second copy.
  ///
  /// Supabase persists and refreshes the token itself. Mirroring that into
  /// shared preferences would be a second source of truth that goes stale the
  /// moment a token is revoked — and the app would trust the stale one.
  Future<void> _restore() async {
    try {
      final session = await _repo.restoreSession();
      state = session == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(session);
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

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

  /// The rep has replaced the password their manager set. Errors are the
  /// screen's to show, beside the field they were typed into.
  Future<void> chooseOwnPassword(String password) async {
    await _repo.chooseOwnPassword(password);
    final current = state;
    if (current is AuthAuthenticated) {
      state = AuthAuthenticated(current.session.withOwnPassword());
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

/// Real connectivity via [connectivity_plus], with an optional manual override
/// so Settings → Simulate offline still works for demos and tests.
class ConnectivityController extends Notifier<bool> {
  bool? _manualOverride;
  var _started = false;

  @override
  bool build() {
    if (!_started) {
      _started = true;
      _listen();
    }
    return _manualOverride ?? true;
  }

  Future<void> _listen() async {
    final connectivity = Connectivity();
    try {
      final initial = await connectivity.checkConnectivity();
      _applyPlatform(initial);
    } catch (_) {
      // Platform plugins can fail in tests; keep last known / default.
    }
    final sub = connectivity.onConnectivityChanged.listen(_applyPlatform);
    ref.onDispose(sub.cancel);
  }

  void _applyPlatform(List<ConnectivityResult> results) {
    if (_manualOverride != null) return;
    final online = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
    state = online;
    if (online) {
      // Fire-and-forget flush when the radio comes back.
      Future.microtask(() async {
        final r = await ref.read(outboxFlusherProvider).flush();
        // A refusal changes the queue as much as a success does — it moves an
        // item out of "waiting" and into "needs you" — so both redraw.
        if (r.handled > 0) _bumpOutbox(ref);
      });
    }
  }

  void toggle() => setOnline(!state);

  /// Manual override used by "Simulate offline". Pass the desired online flag.
  void setOnline(bool value) {
    _manualOverride = value;
    state = value;
    if (value) {
      Future.microtask(() async {
        final r = await ref.read(outboxFlusherProvider).flush();
        // A refusal changes the queue as much as a success does — it moves an
        // item out of "waiting" and into "needs you" — so both redraw.
        if (r.handled > 0) _bumpOutbox(ref);
      });
    }
  }

  /// Drop the override and re-read the platform (used when leaving demo mode).
  Future<void> clearOverride() async {
    _manualOverride = null;
    try {
      final results = await Connectivity().checkConnectivity();
      _applyPlatform(results);
    } catch (_) {
      state = true;
    }
  }
}

final isOnlineProvider =
    NotifierProvider<ConnectivityController, bool>(ConnectivityController.new);

/// Count of records saved locally and awaiting sync (§61).
final pendingSyncCountProvider = Provider<int>((ref) {
  final async = ref.watch(outboxItemsProvider);
  return async.maybeWhen(data: (items) => items.length, orElse: () => 0);
});

/// Geo-fence policy and radius — the company's, from `org_settings`.
///
/// These were literals here, so the console could save a policy and a radius
/// that no phone ever read. They come off the session now, and fall back to
/// the old defaults before anybody has signed in: `warn`, because a rep must
/// never be blocked from recording work they genuinely did.
GeoFencePolicy _policyOf(Ref ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthAuthenticated
      ? state.session.geoFencePolicy
      : GeoFencePolicy.warn;
}

final geoFencePolicyProvider = Provider<GeoFencePolicy>(_policyOf);

final geoFenceRadiusProvider = Provider<double>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthAuthenticated ? state.session.geoFenceRadiusMeters : 50;
});

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

final unreadChatsProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(chatRepositoryProvider).unreadCount();
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
