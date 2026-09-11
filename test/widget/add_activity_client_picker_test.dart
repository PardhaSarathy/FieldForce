/// The client picker on Add Activity has to stay current, and stay findable.
///
/// Both of these were reported from a real phone: a rep added a doctor, came
/// back to log the call, and the doctor was not in the list — and the list had
/// no way to search, so on a real round of two hundred clients it would have
/// been unusable even when the name was there.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaconnect/core/providers/app_providers.dart';
import 'package:pharmaconnect/core/theme/app_theme.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/data/repositories/repositories.dart';
import 'package:pharmaconnect/features/activity/presentation/add_activity_screen.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/client.dart';
import 'package:pharmaconnect/shared/models/organization.dart';

/// Wraps the real mock repository and lets the test add a client to it, the
/// way creating one from the Clients screen would.
class _GrowingClients implements ClientRepository {
  _GrowingClients(this._inner);

  final ClientRepository _inner;
  final _extra = <Client>[];

  void add(Client c) => _extra.add(c);

  @override
  Future<List<Client>> list(Session session,
      {String? query, ClientType? type, String? areaId}) async {
    final base = await _inner.list(session,
        query: query, type: type, areaId: areaId);
    return [...base, ..._extra];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _TestAuth extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();
  void seed(Session s) => state = AuthAuthenticated(s);
}

void main() {
  final store = MockStore.instance;

  Future<(ProviderContainer, _GrowingClients)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final clients = _GrowingClients(MockClientRepository());
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_TestAuth.new),
      clientRepositoryProvider.overrideWithValue(clients),
    ]);
    addTearDown(container.dispose);

    final employee =
        store.seed.employees.firstWhere((e) => e.employeeCode == 'MR1001');
    (container.read(authControllerProvider.notifier) as _TestAuth)
        .seed(Session(employee: employee, loginAt: DateTime(2026, 8, 26)));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const AddActivityScreen(),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    return (container, clients);
  }

  testWidgets('a client added elsewhere turns up in the picker', (tester) async {
    final (container, clients) = await pump(tester);

    // Nobody by this name is in the seeded world, so its appearance below can
    // only come from the reload.
    expect(find.text('Dr. Pardhu Karnati'), findsNothing);

    // Created somewhere else in the app — the Clients screen bumps this.
    clients.add(Client(
      id: 'new-1',
      name: 'Dr. Pardhu Karnati',
      type: ClientType.doctor,
      category: ClientCategory.regular,
      listing: ClientListing.unlisted,
      areaId: 'area-1',
      areaName: 'Begumpet',
      territoryId: 'terr-1',
    ));
    container.read(dataRevisionProvider.notifier).state++;
    // Explicit pumps, not `pumpAndSettle`: the mock repository's latency is a
    // `Future.delayed`, and settling only advances time while frames are
    // scheduled — so a pending delay is never reached.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('Select a client'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Pardhu Karnati'), findsOneWidget,
        reason: 'the picker should have re-read the list');
  });

  testWidgets('and the picker can be searched however short the list is',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Select a client'));
    await tester.pumpAndSettle();

    // The search box is not conditional on the count here: a client list grows.
    expect(find.byType(TextField), findsWidgets,
        reason: 'a client picker is always searchable');
  });
}
