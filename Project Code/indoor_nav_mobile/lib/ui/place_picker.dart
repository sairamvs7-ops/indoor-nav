import 'package:flutter/material.dart';

import '../map/building_map.dart';
import 'node_style.dart';

/// Bottom sheet listing every place, grouped by floor, with a search box.
/// Resolves to the chosen node id, or null if dismissed.
Future<int?> showPlacePicker(BuildContext context, {required BuildingMap map, required String title}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlacePicker(map: map, title: title),
  );
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({required this.map, required this.title});

  final BuildingMap map;
  final String title;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  String _query = '';

  bool _matches(MapNode node) => node.name.toLowerCase().contains(_query.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final floor in widget.map.floors) {
      final places = widget.map
          .nodesOnFloor(floor.level)
          .where((n) => n.type != NodeType.corridor && _matches(n))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (places.isEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(floor.name, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ),
      );
      for (final place in places) {
        rows.add(
          ListTile(
            leading: Icon(iconFor(place.type)),
            title: Text(place.name),
            trailing: place.markerId == null ? null : Text('#${place.markerId}', style: theme.textTheme.bodySmall),
            onTap: () => Navigator.of(context).pop(place.id),
          ),
        );
      }
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(widget.title, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search places',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: rows.isEmpty ? const Center(child: Text('No places match your search.')) : ListView(children: rows),
          ),
        ],
      ),
    );
  }
}
