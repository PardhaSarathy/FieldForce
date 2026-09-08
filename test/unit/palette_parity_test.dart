import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The console's palette must equal the app's.
///
/// This replaces a 631-line generator that emitted `tokens.css` from
/// `AppColors` and — on paper — made drift impossible. In practice it wrote to
/// a path the console does not read, was never committed so never ran, and had
/// a failing test of its own. The two palettes happened to agree; nothing was
/// keeping them that way.
///
/// So: no generation. The console keeps its own file, and this asserts the two
/// say the same thing. A check that runs beats a generator that does not, and
/// forty lines beats six hundred for the same guarantee.
///
/// It reads the sibling checkout and **skips** when it is not there, because a
/// CI box with only this repo should not fail for a file it was never given.
void main() {
  test('every colour the console names matches the app', () {
    final tokens = File(
      Platform.environment['MR_SALES_WEB'] ??
          '${Directory.current.parent.path}/Mr_Sales_Web/src/app/tokens.css',
    );

    if (!tokens.existsSync()) {
      markTestSkipped(
        'the console is not checked out beside this repo — set MR_SALES_WEB '
        'to its path to run this',
      );
      return;
    }

    // `static const brandSoft = Color(0xFFEDF4FF);` → brandSoft: edf4ff
    final dart = <String, String>{};
    final source = File('lib/core/theme/app_colors.dart').readAsStringSync();
    for (final m in RegExp(
      r'static const (\w+) = Color\(0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})\)',
    ).allMatches(source)) {
      dart[m.group(1)!] = m.group(2)!.toLowerCase();
    }
    expect(dart, isNotEmpty, reason: 'no colours parsed out of AppColors');

    // `--brand-soft: #edf4ff;` → brandSoft: edf4ff
    final css = <String, String>{};
    for (final m in RegExp(r'--([a-z0-9-]+):\s*#([0-9a-fA-F]{6})\s*;')
        .allMatches(tokens.readAsStringSync())) {
      final camel = m.group(1)!.split('-').indexed.map((e) {
        final (i, word) = e;
        return i == 0 ? word : word[0].toUpperCase() + word.substring(1);
      }).join();
      css[camel] = m.group(2)!.toLowerCase();
    }
    expect(css, isNotEmpty, reason: 'no tokens parsed out of tokens.css');

    // Only the names both sides use. The console has tokens the app has no
    // concept of — chart marks, table chrome — and the app has colours the
    // console never needed. Neither is drift; a *shared* name disagreeing is.
    final shared = dart.keys.where(css.containsKey).toList();
    expect(shared.length, greaterThan(10),
        reason: 'almost nothing lines up — the naming convention has moved, '
            'and this test is no longer checking anything');

    final drifted = <String>[];
    for (final name in shared) {
      if (dart[name] != css[name]) {
        drifted.add('$name: app #${dart[name]}, console #${css[name]}');
      }
    }

    expect(drifted, isEmpty,
        reason: 'the two palettes have drifted:\n  ${drifted.join('\n  ')}');
  });
}
