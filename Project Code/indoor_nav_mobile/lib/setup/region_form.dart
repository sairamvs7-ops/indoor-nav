import 'package:flutter/material.dart';

import '../map/aruco_markers.dart';
import '../map/building_map.dart';
import '../ui/node_style.dart';
import 'building_draft.dart';

/// What the user decided an area of the generated map is.
class RegionFormResult {
  const RegionFormResult({
    required this.kind,
    this.name = '',
    this.type = NodeType.room,
    this.hasMarker = true,
    this.marker,
    this.link,
    this.delete = false,
  });

  final RegionKind kind;
  final String name;
  final NodeType type;
  final bool hasMarker;
  final int? marker;
  final String? link;

  /// Remove the area from the map entirely (hand-traced areas).
  final bool delete;
}

/// The sheet shown when an area of the generated map is tapped: make it a
/// named room (or washroom, entrance...), a corridor, stairs, a lift, or
/// leave it out.
Future<RegionFormResult?> showRegionForm(
  BuildContext context, {
  required BuildingDraft draft,
  required FloorRegion region,
  required int level,
}) {
  return showModalBottomSheet<RegionFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _RegionForm(draft: draft, region: region, level: level),
    ),
  );
}

class _RegionForm extends StatefulWidget {
  const _RegionForm({required this.draft, required this.region, required this.level});

  final BuildingDraft draft;
  final FloorRegion region;
  final int level;

  @override
  State<_RegionForm> createState() => _RegionFormState();
}

class _RegionFormState extends State<_RegionForm> {
  late final DraftNode? _place = widget.draft.placeFor(widget.region.id, widget.level);
  late RegionKind _kind = widget.region.kind;
  late NodeType _type = _place?.type ??
      switch (widget.region.kind) {
        RegionKind.stairs => NodeType.stairs,
        RegionKind.lift => NodeType.lift,
        _ => NodeType.room,
      };
  late final TextEditingController _name = TextEditingController(text: _place?.name ?? '');
  late final TextEditingController _link = TextEditingController(text: _place?.link ?? '');
  late final TextEditingController _marker = TextEditingController(
    text: (_place?.marker ?? widget.draft.nextFreeMarker())?.toString() ?? '',
  );
  late bool _hasMarker = _place == null || _place.marker != null;
  String? _markerError;

  static const _roomTypes = [NodeType.room, NodeType.washroom, NodeType.entry, NodeType.landmark];

  bool get _isPlace => _kind == RegionKind.room || _kind == RegionKind.stairs || _kind == RegionKind.lift;

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    _marker.dispose();
    super.dispose();
  }

  void _setKind(RegionKind kind) => setState(() {
    _kind = kind;
    if (kind == RegionKind.stairs) _type = NodeType.stairs;
    if (kind == RegionKind.lift) _type = NodeType.lift;
    if (kind == RegionKind.room && _type.isVertical) _type = NodeType.room;
  });

  void _submit() {
    int? marker;
    if (_isPlace && _hasMarker) {
      marker = int.tryParse(_marker.text.trim());
      if (marker == null || marker < 0 || marker >= markerCount) {
        setState(() => _markerError = 'Use a number from 0 to ${markerCount - 1}');
        return;
      }
    }
    Navigator.of(context).pop(
      RegionFormResult(
        kind: _kind,
        name: _name.text,
        type: _type,
        hasMarker: _isPlace && _hasMarker,
        marker: marker,
        link: _type.isVertical ? _link.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkNames = _type.isVertical ? widget.draft.linkNames(_type) : const <String>[];
    final traced = widget.region.id.startsWith('t');
    final place = _place;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(place == null ? 'What is this area?' : 'Edit ${place.name}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in RegionKind.values)
                  ChoiceChip(
                    avatar: Icon(switch (kind) {
                      RegionKind.room => Icons.meeting_room_outlined,
                      RegionKind.corridor => Icons.route,
                      RegionKind.stairs => Icons.stairs_outlined,
                      RegionKind.lift => Icons.elevator_outlined,
                      RegionKind.ignored => Icons.visibility_off_outlined,
                    }, size: 18),
                    label: Text(kind.label),
                    selected: _kind == kind,
                    showCheckmark: false,
                    onSelected: (_) => _setKind(kind),
                  ),
              ],
            ),
            if (_kind == RegionKind.corridor)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Corridors are walkable: the app runs a path down the middle, and rooms join it.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_kind == RegionKind.ignored)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Left out of the map and routes (courtyards, voids, mistakes).', style: theme.textTheme.bodySmall),
              ),
            if (_isPlace) ...[
              if (_kind == RegionKind.room) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final type in _roomTypes)
                      ChoiceChip(
                        avatar: Icon(iconFor(type), size: 16),
                        label: Text(type.label),
                        selected: _type == type,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: place == null,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: switch (_kind) {
                    RegionKind.stairs => 'e.g. Main stairs',
                    RegionKind.lift => 'e.g. Lift A',
                    _ => 'e.g. Room 101, Library',
                  },
                ),
              ),
              if (_type.isVertical) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _link,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Link name',
                    helperText: 'The same name on every floor it reaches connects them.',
                  ),
                ),
                if (linkNames.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final name in linkNames)
                        ActionChip(label: Text(name), onPressed: () => setState(() => _link.text = name)),
                    ],
                  ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Has a marker on the wall'),
                value: _hasMarker,
                onChanged: (v) => setState(() => _hasMarker = v),
              ),
              if (_hasMarker)
                TextField(
                  controller: _marker,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _markerError = null),
                  decoration: InputDecoration(labelText: 'Marker number', errorText: _markerError),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Save')),
            if (traced) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                onPressed: () => Navigator.of(context).pop(const RegionFormResult(kind: RegionKind.ignored, delete: true)),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete this traced area'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
