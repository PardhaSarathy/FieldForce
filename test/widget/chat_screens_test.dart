import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/providers/app_providers.dart';
import 'package:pharmaconnect/core/theme/app_background.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/features/communication/presentation/chat_screens.dart';
import 'package:pharmaconnect/shared/models/engagement.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

void main() {
  final store = MockStore.instance;

  Session sessionFor(String code) {
    final employee =
        store.seed.employees.firstWhere((e) => e.employeeCode == code);
    return Session(employee: employee, loginAt: DateTime(2026, 8, 26));
  }

  Future<void> pumpChat(
    WidgetTester tester, {
    required Widget screen,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_TestAuthController.new),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    (container.read(authControllerProvider.notifier) as _TestAuthController)
        .seed(sessionFor('MR1001'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: screen,
          builder: (context, child) => AppBackground(child: child!),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('failed send shows retry and recovers', (tester) async {
    final repo = _FailOnceChat();
    await pumpChat(
      tester,
      screen: const ChatDetailScreen(threadId: 'ch-1'),
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField), 'Still here');
    await tester.tap(find.byIcon(Icons.send));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Tap to retry'), findsOneWidget);
    expect(find.text('Still here'), findsOneWidget);

    await tester.tap(find.text('Tap to retry'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Tap to retry'), findsNothing);
    expect(find.text('Still here'), findsWidgets);
  });
}

class _FailOnceChat extends MockChatRepository {
  var sends = 0;

  @override
  Future<ChatMessage> send(String threadId, String text) async {
    sends += 1;
    if (sends == 1) {
      throw Exception('offline');
    }
    return super.send(threadId, text);
  }
}

class _TestAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();

  void seed(Session session) => state = AuthAuthenticated(session);
}
