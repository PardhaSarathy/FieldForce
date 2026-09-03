import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards two classes of rot that an audit found nineteen and two instances of.
///
/// Both are invisible to the compiler and to every widget test: the app builds,
/// renders and passes, and a control simply does nothing when pressed. On a
/// demo that is indistinguishable from a broken app.
void main() {
  final lib = Directory('lib');
  final sources = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.uri.pathSegments.last.startsWith('preview_'))
      .toList();

  test('no control is wired to an empty callback', () {
    // `onPressed: () {}` renders an *enabled* button that swallows the tap.
    // Where a feature is not in this build, say so with
    // `showComingWithBackend` — answering is the point.
    final empty = RegExp(r'on(Tap|Pressed|Changed|Submitted):\s*\(\w*\)\s*\{\s*\}');
    final offenders = <String>[];

    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Comments describe the pattern — this file's own guidance does.
        if (line.startsWith('//')) continue;
        if (empty.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}  $line');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'controls that do nothing when pressed:\n${offenders.join('\n')}');
  });

  test('every route constant is registered in the router', () {
    // A constant with no `GoRoute` behind it navigates to the router's
    // "no screen at ..." page — a dead end that only shows up by tapping it.
    final routes = File('lib/core/routing/routes.dart').readAsStringSync();
    final router = File('lib/core/routing/app_router.dart').readAsStringSync();

    final names = [
      ...RegExp(r'static const (\w+) = ').allMatches(routes).map((m) => m[1]!),
      ...RegExp(r'static String (\w+)\(').allMatches(routes).map((m) => m[1]!),
    ].where((n) => n != 'shellRoots');

    final unregistered = <String>[];
    for (final name in names) {
      // Either named directly by the router, or its literal path is declared
      // there — nested routes are written as segments rather than constants.
      final referenced = router.contains('Routes.$name');
      final literal = RegExp("static (?:const|String) $name.*?'([^']+)'")
          .firstMatch(routes)
          ?.group(1);
      // A parameterised route is written '/clients/detail/$id' here and
      // '/clients/detail/:id' in the router, so the two never match verbatim.
      // The literal prefix before the interpolation is what they share.
      final prefix = literal == null
          ? null
          : (literal.contains(r'$')
                ? literal.substring(0, literal.indexOf(r'$')).replaceAll(
                    RegExp(r'/$'),
                    '',
                  )
                : literal);
      final byPath = prefix != null && prefix.isNotEmpty &&
          router.contains(prefix);
      if (!referenced && !byPath) unregistered.add(name);
    }

    expect(unregistered, isEmpty,
        reason: 'route constants with no screen behind them: $unregistered');
  });
}
