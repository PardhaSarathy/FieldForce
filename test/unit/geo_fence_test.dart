import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaconnect/core/location/geo_math.dart';
import 'package:pharmaconnect/shared/enums/app_enums.dart';

/// Geo-fence is the rule most likely to be wrong in a way nobody notices until
/// a month of visit data is unusable, so it is tested independently of any UI
/// or device (§86).
void main() {
  // Apollo Clinic, Andheri East — the anchor used throughout the seed data.
  const clinic = GeoPoint(19.1136, 72.8697);

  group('GeoMath.distanceMeters', () {
    test('is zero for identical points', () {
      expect(GeoMath.distanceMeters(clinic, clinic), closeTo(0, 0.001));
    });

    test('is symmetric', () {
      const other = GeoPoint(19.1200, 72.8750);
      expect(
        GeoMath.distanceMeters(clinic, other),
        closeTo(GeoMath.distanceMeters(other, clinic), 0.001),
      );
    });

    test('matches a known short distance', () {
      // 0.001 degrees of latitude is ~111 m anywhere on Earth.
      const north = GeoPoint(19.1146, 72.8697);
      expect(GeoMath.distanceMeters(clinic, north), closeTo(111, 1.5));
    });

    test('handles the antimeridian without blowing up', () {
      const west = GeoPoint(0, 179.999);
      const east = GeoPoint(0, -179.999);
      // Should be ~222 m across the line, not ~40,000 km around the world.
      expect(GeoMath.distanceMeters(west, east), lessThan(300));
    });
  });

  group('GeoMath.evaluate', () {
    test('verifies a position well inside the fence', () {
      final result = GeoMath.evaluate(
        captured: const GeoPoint(19.11375, 72.86975),
        registered: clinic,
      );

      expect(result.verification, GeoVerification.verified);
      expect(result.isVerified, isTrue);
      expect(result.requiresReason, isFalse);
      expect(result.distanceMeters, lessThan(50));
    });

    test('rejects a position outside the fence but records the distance', () {
      final result = GeoMath.evaluate(
        captured: const GeoPoint(19.1150, 72.8710),
        registered: clinic,
      );

      expect(result.verification, GeoVerification.outOfRange);
      expect(result.requiresReason, isTrue);
      // The distance must still be present — the rep needs to know how far.
      expect(result.distanceMeters, isNotNull);
      expect(result.distanceLabel, isNotNull);
    });

    test('reports unavailable when either point is missing', () {
      expect(
        GeoMath.evaluate(captured: null, registered: clinic).verification,
        GeoVerification.unavailable,
      );
      expect(
        GeoMath.evaluate(captured: clinic, registered: null).verification,
        GeoVerification.unavailable,
      );
    });

    test('flags a mocked provider even when the position is inside', () {
      final result = GeoMath.evaluate(
        captured: clinic,
        registered: clinic,
        isMocked: true,
      );

      expect(result.verification, GeoVerification.suspect);
      expect(result.isVerified, isFalse);
    });

    test('gives the benefit of reported accuracy near the boundary', () {
      // ~62 m away, but the device reports ±20 m — could genuinely be inside.
      const nearBoundary = GeoPoint(19.11416, 72.86995);

      final strict = GeoMath.evaluate(
        captured: nearBoundary,
        registered: clinic,
      );
      final generous = GeoMath.evaluate(
        captured: nearBoundary,
        registered: clinic,
        accuracyMeters: 30,
      );

      expect(strict.verification, GeoVerification.outOfRange);
      expect(generous.verification, GeoVerification.verified);
      // The recorded distance is unchanged — only the verdict differs.
      expect(generous.distanceMeters, closeTo(strict.distanceMeters!, 0.01));
    });

    test('honours a custom radius', () {
      const point = GeoPoint(19.1146, 72.8697); // ~111 m

      expect(
        GeoMath.evaluate(captured: point, registered: clinic, radiusMeters: 50)
            .verification,
        GeoVerification.outOfRange,
      );
      expect(
        GeoMath.evaluate(captured: point, registered: clinic, radiusMeters: 150)
            .verification,
        GeoVerification.verified,
      );
    });

    test('stores the radius in force at capture time', () {
      final result = GeoMath.evaluate(
        captured: clinic,
        registered: clinic,
        radiusMeters: 75,
      );
      // Old records must stay interpretable after an admin changes the policy.
      expect(result.radiusMeters, 75);
    });
  });

  group('GeoMath.allowsVisit', () {
    final verified = GeoMath.evaluate(captured: clinic, registered: clinic);
    final outOfRange = GeoMath.evaluate(
      captured: const GeoPoint(19.1160, 72.8720),
      registered: clinic,
    );

    test('strict blocks an unverified visit', () {
      expect(GeoMath.allowsVisit(verified, GeoFencePolicy.strict), isTrue);
      expect(GeoMath.allowsVisit(outOfRange, GeoFencePolicy.strict), isFalse);
    });

    test('warn allows an out-of-range visit', () {
      expect(GeoMath.allowsVisit(outOfRange, GeoFencePolicy.warn), isTrue);
      expect(outOfRange.requiresReason, isTrue);
    });

    test('off allows everything', () {
      expect(GeoMath.allowsVisit(outOfRange, GeoFencePolicy.off), isTrue);
    });
  });

  group('GeoMath.formatDistance', () {
    test('uses metres below a kilometre', () {
      expect(GeoMath.formatDistance(32.4), '32 m');
      expect(GeoMath.formatDistance(999), '999 m');
    });

    test('switches to kilometres at and above 1000 m', () {
      expect(GeoMath.formatDistance(1000), '1.0 km');
      expect(GeoMath.formatDistance(1449), '1.4 km');
    });

    test('returns null for a missing distance', () {
      expect(GeoMath.formatDistance(null), isNull);
    });
  });
}
