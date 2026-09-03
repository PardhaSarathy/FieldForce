import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/utils/formatters.dart';

/// The smallest defect, and one of the most damaging.
///
/// The app said "1 visits" in eight places. Everything else on a screen can be
/// immaculate and a reader still registers that nobody checked.
void main() {
  group('Fmt.count', () {
    test('one is singular', () {
      expect(Fmt.count(1, 'visit'), '1 visit');
      expect(Fmt.count(1, 'day'), '1 day');
    });

    test('everything else is plural', () {
      expect(Fmt.count(0, 'visit'), '0 visits');
      expect(Fmt.count(2, 'visit'), '2 visits');
      expect(Fmt.count(182, 'visit'), '182 visits');
    });

    test('an irregular plural can be given', () {
      expect(Fmt.count(1, 'entry', 'entries'), '1 entry');
      expect(Fmt.count(3, 'entry', 'entries'), '3 entries');
    });
  });
}
