import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'geo_math.dart';

/// Why a location request failed, so the UI can offer the right recovery
/// (§60) rather than one generic error.
enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  timeout,
  unknown,
}

/// Result of a position request. A sealed pair rather than a nullable position
/// plus an error string, so callers must handle both branches.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  const LocationSuccess({
    required this.point,
    this.accuracyMeters,
    this.isMocked = false,
    required this.capturedAt,
  });

  final GeoPoint point;
  final double? accuracyMeters;
  final bool isMocked;
  final DateTime capturedAt;
}

class LocationError extends LocationResult {
  const LocationError(this.failure);
  final LocationFailure failure;

  String get message => switch (failure) {
        LocationFailure.serviceDisabled =>
          'Location services are turned off. Turn on GPS to verify this visit.',
        LocationFailure.permissionDenied =>
          'PharmaConnect needs location access to verify field visits.',
        LocationFailure.permissionPermanentlyDenied =>
          'Location access is blocked. Enable it in Settings to verify visits.',
        LocationFailure.timeout =>
          'Could not get a GPS fix. Move to an open area and try again.',
        LocationFailure.unknown =>
          'Location is unavailable right now.',
      };
}

abstract interface class LocationService {
  Future<LocationResult> currentPosition();
  Future<bool> isServiceEnabled();
  Future<void> openSettings();
}

/// Real device implementation.
class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationError(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationError(LocationFailure.permissionPermanentlyDenied);
      }
      if (permission == LocationPermission.denied) {
        return const LocationError(LocationFailure.permissionDenied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationSuccess(
        point: GeoPoint(position.latitude, position.longitude),
        accuracyMeters: position.accuracy,
        // A spoofed provider must never silently pass a geo-fence (§9).
        isMocked: position.isMocked,
        capturedAt: position.timestamp,
      );
    } on LocationServiceDisabledException {
      return const LocationError(LocationFailure.serviceDisabled);
    } catch (_) {
      return const LocationError(LocationFailure.timeout);
    }
  }

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}

/// Deterministic stand-in used while there is no backend and, importantly, on
/// platforms with no GPS (desktop, web, simulators).
///
/// It reports a position a fixed short distance from whatever client is being
/// visited, so the verified path is exercised by default. Set [offsetDegrees]
/// large to exercise the out-of-range path — that is how the geo-fence UI gets
/// reviewed without physically walking away from a building.
class MockLocationService implements LocationService {
  MockLocationService({this.anchor, this.offsetDegrees = 0.00022});

  /// The point to report near. Callers set this to the client's registered
  /// location before requesting a position.
  GeoPoint? anchor;

  final double offsetDegrees;

  @override
  Future<LocationResult> currentPosition() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final base = anchor ?? const GeoPoint(19.1136, 72.8697);
    return LocationSuccess(
      point: GeoPoint(
        base.latitude + offsetDegrees,
        base.longitude + offsetDegrees * 0.4,
      ),
      accuracyMeters: 8,
      capturedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<void> openSettings() async {}
}

/// Bound to the mock while the app runs without a backend or a real device.
/// Swap to [GeolocatorLocationService] for on-device builds.
final locationServiceProvider =
    Provider<LocationService>((ref) => MockLocationService());
