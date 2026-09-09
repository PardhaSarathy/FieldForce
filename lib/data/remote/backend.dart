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

import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

/// The organisation this build belongs to.
///
/// It is here because the sign-in address is *derived* from the employee code
/// and the organisation rather than looked up:
///
///     MR1001  +  'mrsales-demo'  ->  mr1001@mrsales-demo.mrsales.local
///
/// A lookup would need a public endpoint answering "does MR1001 exist here",
/// which is an enumeration oracle on the staff list. Deriving asks the server
/// nothing, so a wrong code fails authentication exactly like a wrong
/// password. The cost is that the app is built per company — the same shape
/// the Supabase URL already has. One build serving several organisations
/// would put the choice on the login screen, and this function is where that
/// would go.
const String orgSlug = String.fromEnvironment('ORG_SLUG', defaultValue: 'mrsales-demo');

/// The address behind an employee code. Never shown to anybody: the person
/// types `MR1001`, and this is what Supabase Auth is asked about.
///
/// Must produce byte-for-byte what `public.login_email()` produces in the
/// database, because the account was created there.
String loginEmailFor(String employeeCode) =>
    '${employeeCode.trim().toLowerCase()}@${orgSlug.trim().toLowerCase()}.mrsales.local';

/// Whether a backend is *configured*. Not whether it is reachable, and not
/// whether anybody is signed in — a wrong URL is still "live", and it fails
/// where it is used with the reason attached, rather than silently falling
/// back to seeded data and showing somebody a world that is not theirs.
bool get isLive => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

/// Call once, before [runApp]. Does nothing in fixture mode, which is what
/// keeps a demo build free of any network setup at all.
Future<void> initBackend() async {
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
