import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/building_map.dart';
import '../navigation/navigation_controller.dart';
import '../scanner/marker_detector.dart';
import '../scanner/scanner_screen.dart';
import 'floor_plan_view.dart';
import 'instruction_card.dart';
import 'place_picker.dart';
import 'route_steps.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.createDetector = MarkerDetector.new});

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onNodeTap(BuildContext context, MapNode node) {
    final nav = context.read<NavigationController>();
    nav.selectDestination(node.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Destination set to ${node.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final map = nav.map;
    final floor = map.floor(nav.viewFloor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indoor Nav'),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          InstructionCard(nav: nav, onPickDestination: () => _pickDestination(context)),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: [for (final f in map.floors) ButtonSegment(value: f.level, label: Text(f.name))],
            selected: {nav.viewFloor},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => nav.showFloor(selection.first),
          ),
          const SizedBox(height: 12),
          FloorPlanView(
            map: map,
            floor: floor,
            route: nav.routeNodes,
            currentId: nav.currentNode?.id,
            destinationId: nav.destinationNode?.id,
            onNodeTap: (node) => _onNodeTap(context, node),
          ),
          const SizedBox(height: 4),
          Text(
            'Pinch to zoom · tap a place to go there',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
