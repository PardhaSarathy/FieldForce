import 'dart:math' as math;

import '../../shared/enums/app_enums.dart';

/// A latitude/longitude pair. Deliberately independent of any plugin type so
/// that geo logic stays pure Dart and unit-testable without a device (§86).
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Outcome of validating a captured position against a client's registered
/// location. Carries the evidence, not just the verdict, so the UI can show
/// "32 m from client" and the record can be audited later (§69).
class GeoFenceResult {
  const GeoFenceResult({
    required this.verification,
    required this.radiusMeters,
    this.distanceMeters,
    this.captured,
    this.registered,
    this.capturedAt,
  });

  final GeoVerification verification;

  /// Configured fence radius at the time of capture. Stored per-record because
  /// an admin may change the policy later and old records must stay meaningful.
  final double radiusMeters;

  /// Null when position could not be obtained.
  final double? distanceMeters;

  final GeoPoint? captured;
  final GeoPoint? registered;
  final DateTime? capturedAt;

  bool get isVerified => verification == GeoVerification.verified;

  /// Whether the business rule requires the user to justify proceeding.
  bool get requiresReason => verification == GeoVerification.outOfRange;

  /// Human-readable distance, e.g. "32 m" or "1.4 km".
  String? get distanceLabel => GeoMath.formatDistance(distanceMeters);

  /// The line shown under the geo badge. Phrased as guidance, not an error,
  /// because the rep usually just needs to walk closer.
  String get message {
    return switch (verification) {
      GeoVerification.verified => 'Within range ($distanceLabel from client)',
      GeoVerification.outOfRange =>
        '$distanceLabel from client — move within '
            '${radiusMeters.round()} m to verify',
      GeoVerification.unavailable =>
        'Location unavailable. The visit will be recorded as unverified.',
      GeoVerification.suspect =>
        'A mock location provider was detected. This visit will be flagged.',
    };
  }

  static const unavailable = GeoFenceResult(
    verification: GeoVerification.unavailable,
    radiusMeters: GeoMath.defaultFenceRadiusMeters,
  );
}

abstract final class GeoMath {
  /// Default visit geo-fence (§9).
  static const double defaultFenceRadiusMeters = 50;

  static const double _earthRadiusMeters = 6371008.8;

  /// Great-circle distance in metres between two points (haversine).
  ///
  /// Haversine is accurate to a few metres over the short distances that matter
  /// for a 50 m fence, and unlike a full geodesic solver it has no edge cases
  /// that could wrongly reject a legitimate visit.
  static double distanceMeters(GeoPoint a, GeoPoint b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLat = lat2 - lat1;
    final dLon = _toRadians(b.longitude - a.longitude);

    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);

    return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Validates [captured] against [registered].
  ///
  /// [accuracyMeters], when supplied by the platform, is treated generously:
  /// a reading 55 m away with ±20 m accuracy could genuinely be inside a 50 m
  /// fence, so we compare against `distance - accuracy`. Being strict here
  /// would fail honest reps on cheap handsets indoors.
  static GeoFenceResult evaluate({
    required GeoPoint? captured,
    required GeoPoint? registered,
    double radiusMeters = defaultFenceRadiusMeters,
    double? accuracyMeters,
    bool isMocked = false,
    DateTime? capturedAt,
  }) {
    if (captured == null || registered == null) {
      return GeoFenceResult(
        verification: GeoVerification.unavailable,
        radiusMeters: radiusMeters,
        captured: captured,
        registered: registered,
        capturedAt: capturedAt,
      );
    }

    final distance = distanceMeters(captured, registered);

    if (isMocked) {
      return GeoFenceResult(
        verification: GeoVerification.suspect,
        radiusMeters: radiusMeters,
        distanceMeters: distance,
        captured: captured,
        registered: registered,
        capturedAt: capturedAt,
      );
    }

    final effective =
        accuracyMeters == null ? distance : distance - accuracyMeters;

    return GeoFenceResult(
      verification: effective <= radiusMeters
          ? GeoVerification.verified
          : GeoVerification.outOfRange,
      radiusMeters: radiusMeters,
      distanceMeters: distance,
      captured: captured,
      registered: registered,
      capturedAt: capturedAt,
    );
  }

  /// Whether a visit may proceed under the configured [policy].
  static bool allowsVisit(GeoFenceResult result, GeoFencePolicy policy) {
    return switch (policy) {
      GeoFencePolicy.off => true,
      GeoFencePolicy.warn => true,
      GeoFencePolicy.strict => result.isVerified,
    };
  }

  /// "32 m", "940 m", "1.4 km".
  static String? formatDistance(double? meters) {
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Rough straight-line travel estimate, used for planning hints only.
  static Duration estimateTravel(double meters, {double kmPerHour = 22}) {
    final hours = (meters / 1000) / kmPerHour;
    return Duration(minutes: (hours * 60).ceil());
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
