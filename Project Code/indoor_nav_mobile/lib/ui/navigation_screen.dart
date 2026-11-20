import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/building_map.dart';
import '../navigation/navigation_controller.dart';
import '../scanner/marker_detector.dart';
import '../scanner/scanner_screen.dart';
import 'blueprint_view.dart';
import 'floor_plan_view.dart';
import 'instruction_card.dart';
import 'place_picker.dart';
import 'route_steps.dart';

/// Navigating one building: pick a destination, scan markers, follow the
/// route drawn on each floor.
class NavigationScreen extends StatelessWidget {
  const NavigationScreen({
    super.key,
    required this.map,
    required this.images,
    this.createDetector = MarkerDetector.new,
  });

  final BuildingMap map;
  final FloorImages images;
  final FrameDetector Function() createDetector;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NavigationController(map),
      child: _NavigationView(images: images, createDetector: createDetector),
    );
  }
}

class _NavigationView extends StatelessWidget {
  const _NavigationView({required this.images, required this.createDetector});

  final FloorImages images;
  final FrameDetector Function() createDetector;

  Future<void> _pickDestination(BuildContext context) async {
    final nav = context.read<NavigationController>();
    final id = await showPlacePicker(context, map: nav.map, title: 'Where do you want to go?');
    if (id != null) nav.selectDestination(id);
  }

  Future<void> _pickLocation(BuildContext context) async {
    final nav = context.read<NavigationController>();
    final id = await showPlacePicker(context, map: nav.map, title: 'Where are you now?');
    if (id != null) nav.setCurrentLocation(id);
  }

  Future<void> _scan(BuildContext context) async {
    final nav = context.read<NavigationController>();
    final markerId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(isKnownMarker: nav.map.isKnownMarker, createDetector: createDetector),
      ),
    );
    if (markerId == null || !context.mounted) return;
    final outcome = nav.handleMarker(markerId);
    final here = nav.currentNode?.name;
    final message = switch (outcome) {
      ScanOutcome.arrived => 'You have arrived at $here',
      ScanOutcome.located => 'You are at $here',
      ScanOutcome.unknownMarker => 'Marker $markerId is not on this map',
    };
    _toast(context, message);
  }

  void _onNodeTap(BuildContext context, MapNode node) {
    context.read<NavigationController>().selectDestination(node.id);
    _toast(context, 'Destination set to ${node.name}');
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final map = nav.map;
    final floor = map.floor(nav.viewFloor);
    final theme = Theme.of(context);
    final hasFloorLinks = map.edges.any((e) => e.kind != EdgeKind.walk);

    return Scaffold(
      appBar: AppBar(
        title: Text(map.name),
        actions: [
          IconButton(
            tooltip: 'Set my location',
            icon: const Icon(Icons.my_location),
            onPressed: () => _pickLocation(context),
          ),
          IconButton(tooltip: 'Start over', icon: const Icon(Icons.restart_alt), onPressed: nav.reset),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          InstructionCard(nav: nav, onPickDestination: () => _pickDestination(context)),
          if (hasFloorLinks) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Route', style: theme.textTheme.labelLarge),
                for (final preference in RoutePreference.values)
                  ChoiceChip(
                    label: Text(preference.label),
                    avatar: Icon(switch (preference) {
                      RoutePreference.fastest => Icons.bolt,
                      RoutePreference.stepFree => Icons.accessible,
                      RoutePreference.avoidLifts => Icons.stairs_outlined,
                    }, size: 18),
                    showCheckmark: false,
                    selected: nav.preference == preference,
                    onSelected: (_) => nav.setPreference(preference),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FloorSelector(
            floors: map.floors,
            selected: nav.viewFloor,
            highlighted: {
              if (nav.currentNode != null) nav.currentNode!.floor,
              if (nav.destinationNode != null) nav.destinationNode!.floor,
            },
            onSelected: nav.showFloor,
          ),
          const SizedBox(height: 12),
          FloorPlanView(
            map: map,
            floor: floor,
            images: images,
            route: nav.routeNodes,
            currentId: nav.currentNode?.id,
            destinationId: nav.destinationNode?.id,
            onNodeTap: (node) => _onNodeTap(context, node),
          ),
          const SizedBox(height: 6),
          Text('Pinch to zoom · tap a place to go there', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          if (nav.steps.isNotEmpty) ...[const SizedBox(height: 16), RouteSteps(map: map, steps: nav.steps)],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scan(context),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan marker'),
      ),
    );
  }
}

/// A row of floor chips, scrollable for tall buildings. Floors in
/// [highlighted] (where you are, where you're going) get a dot.
class FloorSelector extends StatelessWidget {
  const FloorSelector({
    super.key,
    required this.floors,
    required this.selected,
    required this.onSelected,
    this.highlighted = const {},
  });

  final List<Floor> floors;
  final int selected;
  final ValueChanged<int> onSelected;
  final Set<int> highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Top floor first reads like a building directory.
          for (final floor in floors.reversed) ...[
            ChoiceChip(
              key: ValueKey('floor-${floor.level}'),
              label: Text(floor.name),
              avatar: highlighted.contains(floor.level)
                  ? Icon(Icons.circle, size: 10, color: theme.colorScheme.secondary)
                  : null,
              showCheckmark: false,
              selected: floor.level == selected,
              onSelected: (_) => onSelected(floor.level),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
