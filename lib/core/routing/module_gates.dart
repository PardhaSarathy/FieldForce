import '../../shared/models/organization.dart';
import 'routes.dart';

/// Which plan module a screen belongs to, or null for screens every plan has.
///
/// Mr Sales plans can leave modules out (Main_Dashboard 008). The database
/// refuses their data either way; this keeps the phone from offering a screen
/// that could only show an error.
String? moduleForRoute(String path) {
  if (path.startsWith(Routes.expenses) || path.startsWith(Routes.expenseReport)) {
    return 'expenses';
  }
  if (path.startsWith('/travel')) return 'tours';
  if (path.startsWith(Routes.resources)) return 'resources';
  if (path.startsWith(Routes.surveys)) return 'surveys';
  if (path.startsWith(Routes.chat)) return 'chat';
  if (path.startsWith(Routes.orders)) return 'orders';
  if (path.startsWith(Routes.attendance)) return 'attendance';
  return null;
}

/// Whether this organisation's plan includes the screen at [path].
bool routeInPlan(Session session, String path) {
  final module = moduleForRoute(path);
  return module == null || session.hasModule(module);
}
