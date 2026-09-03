import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';
import 'package:pharmaconnect/shared/models/client.dart';

Client _client({
  DateTime? specialDate,
  SpecialOccasion? occasion,
  String? note,
  ClientListing listing = ClientListing.listed,
}) {
  return Client(
    id: 'c-1',
    name: 'Dr. Test',
    type: ClientType.doctor,
    category: ClientCategory.coreTarget,
    areaId: 'a-1',
    areaName: 'Andheri',
    territoryId: 't-1',
    listing: listing,
    specialDate: specialDate,
    specialOccasion: occasion,
    specialOccasionNote: note,
  );
}

void main() {
  group('the occasion label', () {
    test('names what the date is', () {
      final c = _client(
        specialDate: DateTime(1980, 3, 14),
        occasion: SpecialOccasion.anniversary,
      );
      expect(c.occasionLabel, 'Anniversary');
    });

    test('an "other" occasion reads as whatever was typed', () {
      final c = _client(
        specialDate: DateTime(1980, 3, 14),
        occasion: SpecialOccasion.other,
        note: 'Clinic founding day',
      );
      expect(c.occasionLabel, 'Clinic founding day');
    });

    test('an "other" with no note still says something', () {
      final c = _client(
        specialDate: DateTime(1980, 3, 14),
        occasion: SpecialOccasion.other,
      );
      expect(c.occasionLabel, 'Special date');
    });

    test('records made before the occasion existed do not crash or lie', () {
      final c = _client(specialDate: DateTime(1980, 3, 14));
      expect(c.occasionLabel, 'Special date');
    });

    test('no date means nothing to label', () {
      expect(_client().occasionLabel, isNull);
      expect(_client().daysUntilOccasion(), isNull);
    });
  });

  group('the countdown', () {
    // Fixed "today" throughout: a countdown test that reads the clock passes
    // in the morning and fails after midnight.
    final today = DateTime(2026, 9, 3, 14, 30);

    test('is zero on the day itself, whatever the year it started', () {
      final c = _client(specialDate: DateTime(1975, 9, 3));
      expect(c.daysUntilOccasion(now: today), 0);
    });

    test('counts whole days, not hours', () {
      // The date is tomorrow but only 9.5 hours away. Comparing timestamps
      // would call this "today".
      final c = _client(specialDate: DateTime(1975, 9, 4));
      expect(c.daysUntilOccasion(now: today), 1);
    });

    test('rolls to next year once the date has passed', () {
      // Yesterday's date is 364 days away, not 365: a full year from 3 Sep
      // 2026 lands on 3 Sep 2027, and this one falls the day before it.
      final c = _client(specialDate: DateTime(1975, 9, 2));
      expect(c.daysUntilOccasion(now: today), 364);
    });

    test('handles a date later this year', () {
      final c = _client(specialDate: DateTime(1975, 12, 25));
      expect(c.daysUntilOccasion(now: today), 113);
    });
  });

  group('copyWith', () {
    test('keeps the fields it used to drop on the floor', () {
      // It never passed `listing` or `specialDate` to the constructor, so every
      // copy silently reset the category to unlisted and wiped the date.
      // Nothing called it on a client, so nothing had lost data yet — editing
      // a client would have been the first thing to.
      final original = _client(
        specialDate: DateTime(1980, 3, 14),
        occasion: SpecialOccasion.other,
        note: 'Clinic founding day',
        listing: ClientListing.listed,
      );

      final copy = original.copyWith(mobile: '9876543210');

      expect(copy.mobile, '9876543210');
      expect(copy.listing, ClientListing.listed);
      expect(copy.specialDate, DateTime(1980, 3, 14));
      expect(copy.specialOccasion, SpecialOccasion.other);
      expect(copy.specialOccasionNote, 'Clinic founding day');
    });
  });
}
