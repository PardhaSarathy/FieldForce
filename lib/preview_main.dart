// Throwaway entry point for the browser preview: signs in as the demo rep so
// a reload lands on Home instead of the login screen, and honours `?r=/route`
// so any screen can be reached without tapping (the preview harness cannot
// click a Flutter canvas). Not shipped — the APK and `flutter run` both build
// lib/main.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  // `?u=ASM201` signs in as someone else. The app is four different apps
  // depending on who is holding it, and checking a manager's screen used to
  // mean editing this file and rebuilding.
  final code = Uri.base.queryParameters['u'] ?? 'MR1001';
  await container.read(authControllerProvider.notifier).login(code, 'demo1234');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PharmaConnectApp(),
    ),
  );

  // After the first frame: before it, the router is not attached yet and the
  // splash redirect lands on Home over the top of anything set here.
  final route = Uri.base.queryParameters['r'];
  if (route != null && route.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => container.read(routerProvider).go(route),
    );
  }
}
