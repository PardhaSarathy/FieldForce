import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'mock_map.dart';

export 'mock_map.dart' show MapMarker, MapMarkerKind;

/// Real OpenStreetMap tiles with the same marker contract as [MockMapCanvas].
class TileMapCanvas extends StatelessWidget {
  const TileMapCanvas({
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

  LatLng _center() {
    if (markers.isEmpty) return const LatLng(17.385, 78.4867);
    final lat =
        markers.map((m) => m.point.latitude).reduce((a, b) => a + b) /
            markers.length;
    final lng =
        markers.map((m) => m.point.longitude).reduce((a, b) => a + b) /
            markers.length;
    return LatLng(lat, lng);
  }

  Color _colorFor(MapMarker m) {
    if (m.color != null) return m.color!;
    return switch (m.kind) {
      MapMarkerKind.self => AppColors.brand,
      MapMarkerKind.person => AppColors.info,
      MapMarkerKind.client => AppColors.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final center = _center();
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: markers.length <= 1 ? 13 : 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mrsales.fieldforce',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                for (final m in markers)
                  Marker(
                    point: LatLng(m.point.latitude, m.point.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: onSelect == null ? null : () => onSelect!(m),
                      child: _Pin(
                        color: _colorFor(m),
                        selected: m.id == selectedId,
                        active: m.isActive,
                        kind: m.kind,
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap',
                  // The tiles are used under ODbL, which asks that the credit
                  // link actually go somewhere.
                  onTap: () => launchUrl(
                    Uri.parse('https://openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  ),
                  textStyle: AppTypography.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.color,
    required this.selected,
    required this.active,
    required this.kind,
  });

  final Color color;
  final bool selected;
  final bool active;
  final MapMarkerKind kind;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      MapMarkerKind.self => Icons.person_pin_circle,
      MapMarkerKind.person => Icons.person_pin,
      MapMarkerKind.client => Icons.place,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: selected || active ? 1 : 0.92),
        border: Border.all(
          color: Colors.white,
          width: selected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: active ? 10 : 4,
            spreadRadius: active ? 2 : 0,
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}

/// Convenience: live tiles when the device can reach the network, schematic
/// mock otherwise (widget tests / offline demos).
class AdaptiveMapCanvas extends StatelessWidget {
  const AdaptiveMapCanvas({
    super.key,
    required this.markers,
    this.selectedId,
    this.onSelect,
    this.height = 320,
    this.preferTiles = true,
  });

  final List<MapMarker> markers;
  final String? selectedId;
  final ValueChanged<MapMarker>? onSelect;
  final double height;
  final bool preferTiles;

  @override
  Widget build(BuildContext context) {
    if (!preferTiles) {
      return MockMapCanvas(
        markers: markers,
        selectedId: selectedId,
        onSelect: onSelect,
        height: height,
      );
    }
    return TileMapCanvas(
      markers: markers,
      selectedId: selectedId,
      onSelect: onSelect,
      height: height,
    );
  }
}
