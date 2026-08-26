import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/location/geo_math.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// What a marker represents. Drives its shape and colour so a glance
/// distinguishes a person from a place.
enum MapMarkerKind {
  /// A team member's last known position.
  person,

  /// A registered client location.
  client,

  /// The signed-in user.
  self,
}

class MapMarker {
  const MapMarker({
    required this.id,
    required this.point,
    required this.label,
    required this.kind,
    this.sublabel,
    this.color,
    this.isActive = false,
  });

  final String id;
  final GeoPoint point;
  final String label;
  final String? sublabel;
  final MapMarkerKind kind;

  /// Overrides the default colour for the kind — used to signal status
  /// (on plan / behind plan) rather than identity.
  final Color? color;

  /// Draws an activity halo. Used for "currently on a visit".
  final bool isActive;
}

/// A schematic map surface.
///
/// This is a **design mockup, not cartography**. A real tile layer needs a Maps
/// API key and billing, which is a later phase. Rather than leave the screen
/// empty or paste a screenshot, this renders the actual marker geometry —
/// positions are projected from real latitude/longitude, so spatial
/// relationships between team members and clients are true even though the
/// streets underneath are generated.
///
/// The generated streets are deterministic (seeded from the bounds), so the map
/// does not reshuffle on every rebuild. Swapping in `google_maps_flutter` later
/// replaces [_MapBasePainter] and keeps the marker layer as it is.
class MockMapCanvas extends StatefulWidget {
  const MockMapCanvas({
    super.key,
    required this.markers,
    this.selectedId,
    this.onSelect,
    this.height = 320,
  });

  final List<MapMarker> markers;
  final String? selectedId;
  final ValueChanged<MapMarker>? onSelect;
  final double height;

  @override
  State<MockMapCanvas> createState() => _MockMapCanvasState();
}

class _MockMapCanvasState extends State<MockMapCanvas> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('No positions to show', style: AppTypography.caption),
        ),
      );
    }

    final bounds = _Bounds.of(widget.markers.map((m) => m.point));

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _controller,
              minScale: 1,
              maxScale: 4,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MapBasePainter(bounds: bounds),
                        ),
                      ),

                      // Client dots sit under the people so a rep is never
                      // hidden behind a place.
                      for (final marker in widget.markers
                          .where((m) => m.kind == MapMarkerKind.client))
                        _positioned(
                          marker,
                          bounds,
                          size,
                          child: const _ClientDot(),
                        ),

                      for (final marker in widget.markers
                          .where((m) => m.kind != MapMarkerKind.client))
                        _positioned(
                          marker,
                          bounds,
                          size,
                          child: _PersonPin(
                            marker: marker,
                            isSelected: marker.id == widget.selectedId,
                            onTap: () => widget.onSelect?.call(marker),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // Honest label — this is geometry, not a street map.
            const Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: _PreviewChip(),
            ),

            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _ZoomControls(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positioned(
    MapMarker marker,
    _Bounds bounds,
    Size size, {
    required Widget child,
  }) {
    final offset = bounds.project(marker.point, size);
    return Positioned(
      left: offset.dx - 22,
      top: offset.dy - 44,
      width: 44,
      height: 48,
      child: child,
    );
  }
}

/// Latitude/longitude extent, padded so markers never sit on the edge.
class _Bounds {
  const _Bounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  factory _Bounds.of(Iterable<GeoPoint> points) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    // Pad the extent, with a floor so a single point still renders sensibly
    // instead of dividing by zero. The northern edge gets extra room because a
    // pin is drawn *above* its anchor point — without it, the topmost marker
    // is clipped by the canvas edge.
    final latSpan = math.max(maxLat - minLat, 0.004);
    final lngSpan = math.max(maxLng - minLng, 0.004);

    return _Bounds(
      minLat: minLat - latSpan * 0.14,
      maxLat: maxLat + latSpan * 0.30,
      minLng: minLng - lngSpan * 0.16,
      maxLng: maxLng + lngSpan * 0.16,
    );
  }

  /// Linear projection. At city scale the error versus a proper Mercator is
  /// far below one pixel, and this keeps the widget dependency-free.
  Offset project(GeoPoint point, Size size) {
    final x = (point.longitude - minLng) / (maxLng - minLng) * size.width;
    // Latitude increases northward; screen y increases downward.
    final y = (maxLat - point.latitude) / (maxLat - minLat) * size.height;
    return Offset(x, y);
  }

  /// Stable seed so the generated streets are identical across rebuilds.
  int get seed =>
      ((minLat + maxLat + minLng + maxLng) * 100000).round().abs();
}

/// Paints the schematic base: land, parks, water and a street network.
class _MapBasePainter extends CustomPainter {
  _MapBasePainter({required this.bounds});

  final _Bounds bounds;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(bounds.seed);

    // Land
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surfaceSecondary,
    );

    _paintWater(canvas, size, rng);
    _paintParks(canvas, size, rng);
    _paintStreets(canvas, size, rng);
    _paintBlocks(canvas, size, rng);
  }

  void _paintWater(Canvas canvas, Size size, math.Random rng) {
    // A single coastline sweeping across one corner — enough to orient the eye
    // without pretending to be a real shoreline.
    final path = Path()
      ..moveTo(size.width * 0.78, 0)
      ..quadraticBezierTo(
        size.width * 0.88, size.height * 0.32,
        size.width * 0.74, size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.66, size.height * 0.82,
        size.width * 0.86, size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFDCE7EC));
  }

  void _paintParks(Canvas canvas, Size size, math.Random rng) {
    final paint = Paint()..color = const Color(0xFFDFE9DF);

    for (var i = 0; i < 3; i++) {
      final left = size.width * (0.06 + rng.nextDouble() * 0.5);
      final top = size.height * (0.1 + rng.nextDouble() * 0.6);
      final w = size.width * (0.10 + rng.nextDouble() * 0.12);
      final h = size.height * (0.09 + rng.nextDouble() * 0.14);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, w, h),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  void _paintStreets(Canvas canvas, Size size, math.Random rng) {
    final minor = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final arterial = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final arterialEdge = Paint()
      ..color = const Color(0xFFE4E0D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    // Minor grid, slightly irregular so it reads as a city rather than graph
    // paper.
    for (var i = 1; i < 9; i++) {
      final y = size.height * (i / 9) + (rng.nextDouble() - 0.5) * 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
    for (var i = 1; i < 8; i++) {
      final x = size.width * (i / 8) + (rng.nextDouble() - 0.5) * 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }

    // Two arterials, drawn edge-first so they read as wider roads.
    final aY = size.height * 0.42;
    final aX = size.width * 0.34;

    for (final paint in [arterialEdge, arterial]) {
      canvas.drawLine(Offset(0, aY), Offset(size.width, aY - 14), paint);
      canvas.drawLine(Offset(aX, 0), Offset(aX + 22, size.height), paint);
    }

    // A diagonal, which every real city has and no grid generator remembers.
    final diagonal = Path()
      ..moveTo(0, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.42, size.height * 0.62,
        size.width * 0.72, size.height * 0.08,
      );
    canvas.drawPath(diagonal, arterialEdge);
    canvas.drawPath(diagonal, arterial);
  }

  void _paintBlocks(Canvas canvas, Size size, math.Random rng) {
    // Faint building footprints for texture. Kept very low contrast so they
    // never compete with the markers.
    final paint = Paint()..color = const Color(0x0F182027);

    for (var i = 0; i < 26; i++) {
      final left = rng.nextDouble() * size.width * 0.72;
      final top = rng.nextDouble() * size.height;
      final w = 8 + rng.nextDouble() * 20;
      final h = 8 + rng.nextDouble() * 16;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, w, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapBasePainter oldDelegate) =>
      oldDelegate.bounds.seed != bounds.seed;
}

/// A registered client — a small dot, because places are context, not subjects.
class _ClientDot extends StatelessWidget {
  const _ClientDot();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: AppColors.sand,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
      ),
    );
  }
}

/// A team member's position. Selected state grows the pin and reveals the name,
/// so the map stays readable when several reps work the same cluster.
class _PersonPin extends StatelessWidget {
  const _PersonPin({
    required this.marker,
    required this.isSelected,
    required this.onTap,
  });

  final MapMarker marker;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = marker.color ??
        (marker.kind == MapMarkerKind.self
            ? AppColors.info
            : AppColors.brand);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                marker.label.split(' ').first,
                style: AppTypography.badge.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 2),
          Stack(
            alignment: Alignment.center,
            children: [
              if (marker.isActive)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: isSelected ? 26 : 22,
                height: isSelected ? 26 : 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.22),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  marker.kind == MapMarkerKind.self
                      ? Icons.my_location
                      : Icons.person,
                  size: isSelected ? 14 : 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          // Pin tail
          CustomPaint(
            size: const Size(8, 6),
            painter: _PinTailPainter(color: AppColors.surface),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  const _PinTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_outlined,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text('Design preview · positions are real',
              style: AppTypography.badge
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.controller});

  final TransformationController controller;

  void _zoom(double factor) {
    final current = controller.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 4.0);
    // Scale about the centre by rebuilding the matrix rather than composing,
    // so repeated taps cannot drift the view off-canvas.
    controller.value = Matrix4.identity()..scaleByDouble(target, target, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ZoomButton(icon: Icons.add, onTap: () => _zoom(1.5)),
        const SizedBox(height: AppSpacing.xs),
        _ZoomButton(icon: Icons.remove, onTap: () => _zoom(1 / 1.5)),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
