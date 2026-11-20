import 'package:flutter/material.dart';

import '../map/building_map.dart';
import '../routing/directions.dart';

/// The remaining route as a list of steps. The first step is what to do next.
class RouteSteps extends StatelessWidget {
  const RouteSteps({super.key, required this.map, required this.steps, this.onShowFloorChange});

  final BuildingMap map;
  final List<RouteStep> steps;

  /// Replays the 3D floor-change view for a lift or stairs step.
  final ValueChanged<RouteStep>? onShowFloorChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stops = steps.length == 1 ? '1 stop' : '${steps.length} stops';
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Route · $stops to go', style: theme.textTheme.titleMedium),
          ),
          for (final (i, step) in steps.indexed)
            ListTile(
              dense: true,
              selected: i == 0,
              leading: Icon(step.changesFloor ? Icons.swap_vert : Icons.directions_walk),
              title: Text(step.instruction),
              subtitle: Text(map.floor(step.to.floor).name),
              trailing: step.changesFloor && onShowFloorChange != null
                  ? IconButton(
                      tooltip: 'See in 3D',
                      icon: const Icon(Icons.view_in_ar),
                      onPressed: () => onShowFloorChange!(step),
                    )
                  : (i == 0 ? const Text('Next') : null),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
