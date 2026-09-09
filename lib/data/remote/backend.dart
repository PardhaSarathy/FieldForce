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
