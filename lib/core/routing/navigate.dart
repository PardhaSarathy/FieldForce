import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../../features/shell/presentation/app_shell.dart';
import 'routes.dart';

/// Navigates to [route] with the verb that route actually needs.
///
/// A tab root lives on its own branch navigator inside the shell's indexed
/// stack. Pushing one puts the screen on a branch that is not on screen, so
/// nothing appears to happen — the only symptom is a tap that does nothing.
/// Everything else is a full-screen route above the shell and must be pushed
/// so the user keeps a back button.
///
/// **A tab root for whom.** [Routes.shellRoots] lists every route that is a
/// tab for *somebody*, and the bar differs by role — My Activity is a manager
/// tab, and a rep reaches it from the module grid. Sending a rep there with
/// `go` switched them onto a branch that is not in their bar: no tab lit, no
/// back arrow, no history to pop, and the Android back gesture closed the app
/// outright. So the verb is decided against the signed-in user's own tabs, not
/// against the global set.
///
/// Menus, tiles and cards should call this rather than choosing for
/// themselves; the correct verb is a property of the destination *and* of who
/// is looking at it.
void navigateTo(BuildContext context, String route) {
  final router = GoRouter.of(context);
  if (!Routes.shellRoots.contains(route)) {
    router.push(route);
    return;
  }

  final container = ProviderScope.containerOf(context, listen: false);
  final session = container.read(sessionProvider);
  final tabs = destinationsFor(
    isManager: session.isManager,
  ).map((d) => d.route);

  if (tabs.contains(route)) {
    router.go(route);
  } else {
    router.push(route);
  }
}
