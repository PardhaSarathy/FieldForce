/// Pulls the server sentence out of a PostgrestException wrapper when present.
String readablePostgrestError(Object e, {required String fallback}) {
  final raw = e.toString();
  final match = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw);
  if (match != null) return match.group(1)!.trim();
  return fallback;
}
