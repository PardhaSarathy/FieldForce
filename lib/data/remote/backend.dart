/// The connection, and whether there is one.
///
/// The app has two modes and both are real. **Fixture mode** runs on
/// [MockDataset] with no network at all — it is what a demo build is, what the
/// tests run against, and what every screen was built for. **Live mode** talks
/// to Supabase.
///
/// Which one is decided at build time, by `--dart-define`, so a release built
/// without the keys cannot accidentally reach a company's real data:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_KEY=<publishable key>
/// ```
///
/// The publishable key is meant to be shipped to clients; every table behind
/// it is under row-level security that resolves the caller's organisation from
/// their token. The service-role key must never appear in a build.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

/// Compile-time default organisation for single-tenant / demo APKs.
///
/// Multi-customer production builds still ship one APK; the login screen sets
/// [activeOrgSlug] at runtime (company code). This define remains the fallback
/// when nothing has been chosen yet (and for fixture demos).
const String defaultOrgSlug =
    String.fromEnvironment('ORG_SLUG', defaultValue: 'mrsales-demo');

const _prefsOrgKey = 'mrsales.active_org_slug';

String _activeOrgSlug = defaultOrgSlug;

/// Organisation currently selected for deriving login emails.
String get activeOrgSlug => _activeOrgSlug;

/// Normalise a company code / org slug typed on the login screen.
String normalizeOrgSlug(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-');

/// Persist and activate the company code used to derive field login emails.
Future<void> setActiveOrgSlug(String raw) async {
  final slug = normalizeOrgSlug(raw);
  if (slug.isEmpty) {
    throw ArgumentError('Company code is required.');
  }
  _activeOrgSlug = slug;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsOrgKey, slug);
}

/// Restore the last company code after process death. Call from [initBackend].
Future<void> restoreActiveOrgSlug() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefsOrgKey);
  if (saved != null && saved.trim().isNotEmpty) {
    _activeOrgSlug = normalizeOrgSlug(saved);
  }
}

/// Kept for older call sites / docs that still say [orgSlug].
@Deprecated('Use activeOrgSlug')
String get orgSlug => activeOrgSlug;

/// The address behind an employee code. Never shown to anybody: the person
/// types `MR1001`, and this is what Supabase Auth is asked about.
///
/// Must produce byte-for-byte what `public.login_email()` produces in the
/// database, because the account was created there.
String loginEmailFor(String employeeCode, {String? org}) =>
    '${employeeCode.trim().toLowerCase()}@${(org ?? activeOrgSlug).trim().toLowerCase()}.mrsales.local';

/// Whether a backend is *configured*. Not whether it is reachable, and not
/// whether anybody is signed in — a wrong URL is still "live", and it fails
/// where it is used with the reason attached, rather than silently falling
/// back to seeded data and showing somebody a world that is not theirs.
bool get isLive => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

/// Call once, before [runApp]. Does nothing in fixture mode, which is what
/// keeps a demo build free of any network setup at all.
Future<void> initBackend() async {
  await restoreActiveOrgSlug();
  if (!isLive) return;
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
}

/// The client, or a clear error instead of a null dereference further down.
SupabaseClient get db {
  if (!isLive) {
    throw StateError(
      'No backend is configured. Build with --dart-define=SUPABASE_URL=... '
      'and --dart-define=SUPABASE_KEY=...',
    );
  }
  return Supabase.instance.client;
}
