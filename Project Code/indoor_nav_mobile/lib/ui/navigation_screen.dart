import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../map/building_map.dart';
import '../navigation/device_sensors.dart';
import '../navigation/live_walk.dart';
import '../navigation/navigation_controller.dart';
import '../scanner/marker_detector.dart';
import '../scanner/scanner_screen.dart';
import '../routing/directions.dart';
import 'blueprint_view.dart';
import 'floor_change_view.dart';
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
    this.motionSensors = DeviceMotionSensors.new,
    this.speaker = DeviceSpeaker.new,
  });

  final BuildingMap map;
  final FloorImages images;
  final FrameDetector Function() createDetector;

  /// Sensors and voice for "Start walking"; injected so tests can fake them.
  final MotionSensors Function() motionSensors;
  final Speaker Function() speaker;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NavigationController(map),
      child: Builder(
        builder: (context) => ChangeNotifierProvider(
          create: (context) => LiveWalk(
            nav: context.read<NavigationController>(),
            sensors: motionSensors,
            speaker: LazySpeaker(speaker),
            onTurn: () => unawaited(HapticFeedback.heavyImpact()),
          ),
          child: _NavigationView(images: images, createDetector: createDetector),
        ),
      ),
    );
  }
}

class _NavigationView extends StatefulWidget {
  const _NavigationView({required this.images, required this.createDetector});

  final FloorImages images;
  final FrameDetector Function() createDetector;

  @override
  State<_NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<_NavigationView> {
  late final NavigationController _nav = context.read<NavigationController>();
  MapNode? _lastNode;

  FloorImages get images => widget.images;
  FrameDetector Function() get createDetector => widget.createDetector;

  @override
  void initState() {
    super.initState();
    _lastNode = _nav.currentNode;
    _nav.addListener(_onNavigationChanged);
  }

  @override
  void dispose() {
    _nav.removeListener(_onNavigationChanged);
    super.dispose();
  }

  /// Moving from a lift or stairs on one floor to one on another floor means
  /// you just changed floors: show it.
  void _onNavigationChanged() {
    final before = _lastNode;
    final now = _nav.currentNode;
    _lastNode = now;
    if (before == null || now == null || before.floor == now.floor) return;
    if (!before.type.isVertical || !now.type.isVertical) return;
    showFloorChange(context, map: _nav.map, images: images, from: before, to: now, route: _nav.routeNodes);
  }

  void _replayFloorChange(RouteStep step) => showFloorChange(
    context,
    map: _nav.map,
    images: images,
    from: step.from,
    to: step.to,
    route: _nav.routeNodes,
  );

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

  /// Re-locate: forget where you are, keep the destination, and scan the
  /// nearest marker to be routed from there.
  Future<void> _relocate(BuildContext context) async {
    context.read<NavigationController>().clearLocation();
    await _scan(context);
  }

  Future<void> _startWalking(BuildContext context) async {
    final walk = context.read<LiveWalk>();
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Walk with the phone', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'Hold the phone in front of you and face the way the route leaves your dot. '
                'Your steps then move you along the route, places tick off as you pass them, '
                'and turns are spoken. Scan any marker to correct your position.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.directions_walk),
                label: const Text("I'm facing the route, start"),
              ),
            ],
          ),
        ),
      ),
    );
    if (go ?? false) walk.start();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    final walk = context.watch<LiveWalk>();
    final map = nav.map;
    final floor = map.floor(nav.viewFloor);
    final live = walk.position;
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
          InstructionCard(
            nav: nav,
            onPickDestination: () => _pickDestination(context),
            livePrompt: walk.active ? walk.prompt : null,
            liveRemaining: walk.active ? walk.remainingMetres : null,
          ),
          if (walk.active) ...[
            const SizedBox(height: 10),
            _WalkBar(walk: walk, map: map),
          ] else if (nav.currentNode != null && nav.steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _startWalking(context),
              icon: const Icon(Icons.directions_walk),
              label: const Text('Start walking'),
            ),
          ],
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
            live: live != null && live.$1 == floor.level ? Offset(live.$2, live.$3) : null,
            onNodeTap: (node) => _onNodeTap(context, node),
          ),
          const SizedBox(height: 6),
          Text('Pinch to zoom · tap a place to go there', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          if (nav.steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            RouteSteps(
              map: map,
              steps: nav.steps,
              onShowFloorChange: _replayFloorChange,
              onRelocate: () => _relocate(context),
            ),
          ],
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

/// While walking: progress, the floor-change fallback, and Stop.
class _WalkBar extends StatelessWidget {
  const _WalkBar({required this.walk, required this.map});

  final LiveWalk walk;
  final BuildingMap map;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leg = walk.waitingForFloorChange ? walk.next : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(walk.offRoute ? Icons.wrong_location_outlined : Icons.directions_walk, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    walk.offRoute ? 'Off the route' : 'Following your steps · ${walk.stepCount} steps',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(onPressed: walk.stop, icon: const Icon(Icons.stop_circle_outlined), label: const Text('Stop')),
              ],
            ),
            if (leg != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: OutlinedButton.icon(
                  onPressed: walk.arrivedOnFloor,
                  icon: const Icon(Icons.check),
                  label: const Text("I've changed floor"),
                ),
              ),
          ],
        ),
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
