import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/data/mock/fixture_world.dart';

/// The app's world must be the fixture's world.
///
/// `fixture_world.dart` is generated from the console's
/// `fixture/mrsales-world.json`, and a generator nobody runs guarantees
/// nothing — this repo has already retired one that wrote to a path nothing
/// read and was never invoked. So this compares the two directly.
///
/// It compares *content* rather than a digest, for two reasons: a digest
/// needs a hashing dependency this app has deliberately not taken, and a
/// digest can only say "different" where this can say which record. When a
/// regenerated fixture has not reached the app, the failure names the row.
///
/// Skips when the console is not checked out beside this repo — a box with
/// only this one should not fail for a file it was never given.
void main() {
  final path = Platform.environment['MR_SALES_WEB'] ??
      '${Directory.current.parent.path}/Mr_Sales_Web/fixture/mrsales-world.json';
  final file = File(path);

  Map<String, dynamic> world() =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  List<Map<String, dynamic>> rows(String key) =>
      (world()[key] as List).cast<Map<String, dynamic>>();

  const regenerate = 'run:  cd ../Mr_Sales_Web && npm run app-world';

  setUpAll(() {
    if (!file.existsSync()) {
      markTestSkipped('the console is not beside this repo — set MR_SALES_WEB');
    }
  });

  test('every territory, area and cluster', () {
    if (!file.existsSync()) return;
    expect(fixtureTerritories.map((t) => t.id).toList(),
        rows('territories').map((t) => t['id']).toList(), reason: regenerate);
    expect(fixtureAreas.map((a) => a.id).toList(),
        rows('areas').map((a) => a['id']).toList(), reason: regenerate);
    expect(fixtureClusters.map((c) => c.id).toList(),
        rows('clusters').map((c) => c['id']).toList(), reason: regenerate);
  });

  test('every employee, by code and by name', () {
    if (!file.existsSync()) return;
    final want = rows('employees');
    expect(fixtureEmployees.length, want.length, reason: regenerate);
    for (var i = 0; i < want.length; i++) {
      expect(fixtureEmployees[i].employeeCode, want[i]['code'], reason: regenerate);
      expect(fixtureEmployees[i].name, want[i]['name'], reason: regenerate);
      expect(fixtureEmployees[i].managerId, want[i]['managerId'], reason: regenerate);
    }
  });

  test('every client, and who owns it', () {
    if (!file.existsSync()) return;
    final want = rows('clients');
    expect(fixtureClients.length, want.length, reason: regenerate);
    for (var i = 0; i < want.length; i++) {
      expect(fixtureClients[i].id, want[i]['id'], reason: regenerate);
      expect(fixtureClients[i].name, want[i]['name'], reason: regenerate);
      expect(fixtureClients[i].ownerEmployeeId, want[i]['ownerEmployeeId'],
          reason: regenerate);
    }
  });

  test('every product', () {
    if (!file.existsSync()) return;
    final want = rows('products');
    expect(fixtureProducts.map((p) => p.code).toList(),
        want.map((p) => p['code']).toList(), reason: regenerate);
  });
}
