/// What the phone says about a resource file before it has fetched anything.
///
/// Download used to answer "Downloads arrive with the backend" whatever was
/// behind the button. It now opens the real file, so the card has to describe
/// that file honestly: its kind, its size, and — for fixture content — that
/// there is no file to open at all.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaconnect/data/repositories/api_repositories.dart';
import 'package:pharmaconnect/data/repositories/mock_repositories.dart';
import 'package:pharmaconnect/shared/models/field_ops.dart';

void main() {
  group('the kind of file', () {
    test('is read from the stored type first', () {
      expect(ApiResourceRepository.fileTypeFor('application/pdf', 'x/y.jpg'), 'PDF');
      expect(ApiResourceRepository.fileTypeFor('image/png', 'x/y.pdf'), 'IMAGE');
      expect(ApiResourceRepository.fileTypeFor('image/webp', null), 'IMAGE');
    });

    test('falls back to the extension when no type was stored', () {
      expect(ApiResourceRepository.fileTypeFor(null, 'org/resources/a.JPEG'), 'IMAGE');
      expect(ApiResourceRepository.fileTypeFor(null, 'org/resources/a.pdf'), 'PDF');
      expect(ApiResourceRepository.fileTypeFor(null, null), 'PDF');
    });
  });

  group('the size label', () {
    test('reads the way a person would say it', () {
      expect(ApiResourceRepository.sizeLabelFor(512), '512 B');
      expect(ApiResourceRepository.sizeLabelFor(840 * 1024), '840 KB');
      expect(ApiResourceRepository.sizeLabelFor((2.4 * 1024 * 1024).round()), '2.4 MB');
      expect(ApiResourceRepository.sizeLabelFor(23 * 1024 * 1024), '23 MB');
    });

    test('says nothing rather than "0 B" when the size is unknown', () {
      expect(ApiResourceRepository.sizeLabelFor(null), isNull);
      expect(ApiResourceRepository.sizeLabelFor(0), isNull);
    });
  });

  test('a resource knows whether there is a file behind it', () {
    final withFile = Resource(
      id: 'r1', title: 'Price list', category: 'Price List',
      updatedAt: DateTime(2026, 9, 15), storagePath: 'org/resources/r1.pdf',
    );
    final fixture = Resource(
      id: 'r2', title: 'Sample', category: 'Document', updatedAt: DateTime(2026, 9, 15),
    );
    expect(withFile.hasFile, isTrue);
    expect(fixture.hasFile, isFalse);
  });

  test('the offline build offers no link, because fixtures have no file', () async {
    final repo = MockResourceRepository();
    final any = (await repo.list()).first;
    expect(await repo.fileUrl(any), isNull);
  });
}
