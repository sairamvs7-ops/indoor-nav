import 'package:flutter/material.dart';

import '../map/building_map.dart';
import '../scanner/marker_detector.dart';
import '../scanner/scanner_screen.dart';
import '../ui/app_theme.dart';
import '../ui/blueprint_view.dart';
import '../ui/generated_map_painter.dart';
import '../ui/node_style.dart';
import 'marker_sheet.dart';
import 'share_actions.dart';

/// Tells the person setting up the building which marker goes where: print
/// them, stick each one at the place shown, then test-scan to check.
class MarkerGuideScreen extends StatefulWidget {
  const MarkerGuideScreen({
    super.key,
    required this.map,
    required this.images,
    this.createDetector = MarkerDetector.new,
  });

  final BuildingMap map;
  final FloorImages images;
  final FrameDetector Function() createDetector;

  @override
  State<MarkerGuideScreen> createState() => _MarkerGuideScreenState();
}

class _MarkerGuideScreenState extends State<MarkerGuideScreen> {
  final Set<int> _verified = {};
  bool _exporting = false;

  BuildingMap get map => widget.map;

  Future<void> _print() async {
    setState(() => _exporting = true);
    try {
      await shareMarkerPdf(context, map);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _testScan() async {
    final markerId = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ScannerScreen(isKnownMarker: (_) => true, createDetector: widget.createDetector)),
    );
    if (markerId == null || !mounted) return;
    final place = map.nodeForMarker(markerId);
    if (place != null) setState(() => _verified.add(markerId));
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(place == null ? Icons.help_outline : Icons.check_circle, size: 40),
        title: Text('Marker $markerId'),
        content: Text(
          place == null
              ? "This marker isn't used in ${map.name}. Take it down, or give a place this marker number."
              : 'Belongs at ${place.name} on ${map.floor(place.floor).name}. '
                    'If that is not where it is stuck, move it there.',
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _showOnMap(MapNode place) {
    final floor = map.floor(place.floor);
    final colors = MapColors.resolve(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marker ${place.markerId} · ${place.name}', style: Theme.of(context).textTheme.titleLarge),
              Text(floor.name),
              const SizedBox(height: 12),
              BlueprintView(
                image: floor.hasGeneratedMap ? null : widget.images(floor.image),
                underlay: floor.hasGeneratedMap
                    ? (_) => GeneratedMapPainter(
                        regions: floor.regions,
                        drawingWidth: floor.width,
                        style: MapStyle.of(Theme.of(context).brightness),
                        names: regionNames(map, floor.level),
                        selectedRegion: place.region,
                      )
                    : null,
                imageWidth: floor.width,
                imageHeight: floor.height,
                overlay: (scale) => _PinPainter(Offset(place.x * scale, place.y * scale), colors.destination),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final places = placesWithMarkers(map);
    final rows = <Widget>[];
    int? lastFloor;
    for (final place in places) {
      if (place.floor != lastFloor) {
        lastFloor = place.floor;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(
              map.floor(place.floor).name,
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        );
      }
      final verified = _verified.contains(place.markerId);
      rows.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: MarkerView(markerId: place.markerId!, size: 56),
            title: Text('Marker ${place.markerId}'),
            subtitle: Row(
              children: [
                Icon(iconFor(place.type), size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text('Stick at ${place.name}')),
              ],
            ),
            trailing: verified
                ? Icon(Icons.verified, color: theme.colorScheme.primary, semanticLabel: 'Scanned OK')
                : const Icon(Icons.map_outlined),
            onTap: () => _showOnMap(place),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Markers')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${places.length} markers for ${map.name}', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Print the PDF (one marker per page, keep the white border).\n'
                    '2. Stick each marker at the place listed, at eye level. Tap a row to see the spot.\n'
                    '3. Use Test scan on each marker to check it is in the right place.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _exporting ? null : _print,
                    icon: _exporting
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_outlined),
                    label: const Text('Print or share markers (PDF)'),
                  ),
                ],
              ),
            ),
          ),
          ...rows,
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _testScan,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(_verified.isEmpty ? 'Test scan' : 'Test scan (${_verified.length}/${places.length} OK)'),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.at, this.color);

  final Offset at;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawCircle(at, 22, Paint()..color = color.withValues(alpha: 0.25))
      ..drawCircle(at, 10, Paint()..color = Colors.white)
      ..drawCircle(at, 8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.at != at || old.color != color;
}
