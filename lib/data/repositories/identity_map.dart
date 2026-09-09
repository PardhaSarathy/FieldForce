/// Where the fixture's ids and the database's uuids meet.
///
/// Live, an employee's **uuid is the identity** — it is what `Session` carries,
/// what the console shows in a URL, and what every live query uses. The fixture
/// does not vanish, because most modules here still run on it and thousands of
/// activities, clients and day plans point at `emp-1`.
///
/// So the seed becomes a translation table rather than an authority, and this
/// is the only thing that remembers it. Only the **mock** repositories consult
/// it, to find the seeded demo content belonging to a live person; the live
/// repositories never touch it.
///
/// That puts the compatibility layer exactly where the incompleteness is, and
/// it shrinks on its own: a module that gets a real table stops consulting the
/// map, and when the last one does this file is deleted.
library;

import '../mock/mock_dataset.dart';

class IdentityMap {
  final Map<String, String> _uuidByCode = {};

  void remember(String code, String uuid) => _uuidByCode[code] = uuid;
  void rememberAll(Map<String, String> byCode) => _uuidByCode.addAll(byCode);
  void clear() => _uuidByCode.clear();

  bool get isEmpty => _uuidByCode.isEmpty;

  String? uuidForCode(String code) => _uuidByCode[code];

  String? codeForUuid(String uuid) {
    for (final e in _uuidByCode.entries) {
      if (e.value == uuid) return e.key;
    }
    return null;
  }

  /// The seeded record id for a live employee, when the seed knows them.
  String? fixtureIdForUuid(String uuid) {
    final code = codeForUuid(uuid);
    if (code == null) return null;
    return MockDataset.instance.employees
        .where((e) => e.employeeCode == code)
        .firstOrNull
        ?.id;
  }

  /// The live uuid behind a seeded record id.
  String? uuidForFixtureId(String fixtureId) {
    final e = MockDataset.instance.employees
        .where((x) => x.id == fixtureId)
        .firstOrNull;
    return e == null ? null : _uuidByCode[e.employeeCode];
  }

  /// Whatever id the *seed* knows this person by.
  ///
  /// In fixture mode nothing is remembered and the id passes straight through.
  /// Live it turns a Supabase uuid into `emp-1`, and returns the uuid unchanged
  /// for somebody the seed has never heard of — who then simply has no seeded
  /// history, which is the truth rather than a failure.
  String seeded(String employeeId) =>
      fixtureIdForUuid(employeeId) ?? employeeId;
}

final identity = IdentityMap();
