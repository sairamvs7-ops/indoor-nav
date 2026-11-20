import 'dart:async';

import 'package:flutter/material.dart';

import '../map/building_map.dart';
import '../scanner/marker_detector.dart';
import '../storage/building_repository.dart';
import '../ui/blueprint_view.dart';
import '../ui/navigation_screen.dart';
import 'blueprint_picker.dart';
import 'building_checks.dart';
import 'building_draft.dart';
import 'floor_editor_screen.dart';
import 'marker_guide_screen.dart';
import 'share_actions.dart';
import 'walk_recorder_screen.dart';

/// Setting up a building: its floors (one blueprint each), what still needs
/// doing, and the way on to markers and navigation.
class BuildingEditorScreen extends StatefulWidget {
  const BuildingEditorScreen({
    super.key,
    required this.repository,
    required this.buildingId,
    this.createDetector = MarkerDetector.new,
  });

  final BuildingRepository repository;
  final String buildingId;
  final FrameDetector Function() createDetector;

  @override
  State<BuildingEditorScreen> createState() => _BuildingEditorScreenState();
}

class _BuildingEditorScreenState extends State<BuildingEditorScreen> {
  BuildingDraft? _draft;
  Object? _loadError;
  late final FloorImages _images = folderFloorImages(widget.repository.directoryOf(widget.buildingId));

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final json = await widget.repository.readJson(widget.buildingId);
      if (!mounted) return;
      setState(() {
        _draft = BuildingDraft.fromJson(json, save: (data) => widget.repository.writeJson(widget.buildingId, data))
          ..addListener(_redraw);
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _redraw() => setState(() {});

  @override
  void dispose() {
    final draft = _draft;
    if (draft != null) {
      draft.removeListener(_redraw);
      unawaited(draft.flush().whenComplete(draft.dispose));
    }
    super.dispose();
  }

  Future<void> _addFloor() async {
    final draft = _draft!;
    final picked = await pickBlueprint(context);
    if (picked == null || !mounted) return;
    final image = await widget.repository.addImage(widget.buildingId, picked.bytes, extension: picked.extension);
    if (!mounted) return;
    final suggested = draft.floors.isEmpty ? 'Ground Floor' : 'Floor ${draft.floors.length}';
    final name = await _askText(title: 'Name this floor', initial: suggested, label: 'Floor name');
    final level = draft.addFloor(
      name: (name == null || name.trim().isEmpty) ? suggested : name,
      image: image,
      width: picked.width,
      height: picked.height,
    );
    final scale = picked.metresPerPixel;
    if (scale != null) draft.calibrateFloor(level, pixels: 1, metres: scale); // CAD drawings know their scale
    if (mounted) await _openFloor(level);
  }

  Future<void> _replaceDrawing(DraftFloor floor) async {
    final picked = await pickBlueprint(context);
    if (picked == null) return;
    final image = await widget.repository.addImage(widget.buildingId, picked.bytes, extension: picked.extension);
    _draft!.replaceFloorImage(floor.level, image: image, width: picked.width, height: picked.height);
  }

  Future<void> _deleteFloor(DraftFloor floor) async {
    final places = _draft!.nodesOn(floor.level).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${floor.name}?'),
        content: Text('This removes its blueprint and $places places from this building.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok ?? false) _draft!.removeFloor(floor.level);
  }

  Future<void> _openFloor(int level) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FloorEditorScreen(draft: _draft!, level: level, images: _images),
    ),
  );

  Future<String?> _askText({required String title, required String initial, required String label}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('OK')),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _rename() async {
    final draft = _draft!;
    final name = await _askText(title: 'Building name', initial: draft.name, label: 'Name');
    if (name != null) draft.rename(name);
  }

  Future<void> _renameFloor(DraftFloor floor) async {
    final name = await _askText(title: 'Floor name', initial: floor.name, label: 'Name');
    if (name != null) _draft!.renameFloor(floor.level, name);
  }

  void _openNavigation(BuildingMap map) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NavigationScreen(map: map, images: _images, createDetector: widget.createDetector),
    ),
  );

  void _openMarkers(BuildingMap map) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MarkerGuideScreen(map: map, images: _images, createDetector: widget.createDetector),
    ),
  );

  void _openWalk() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WalkRecorderScreen(draft: _draft!, createDetector: widget.createDetector),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Building')),
        body: Center(child: Text('This building could not be opened.\n$_loadError', textAlign: TextAlign.center)),
      );
    }
    if (draft == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    final (map, buildError) = draft.tryBuild();
    final issues = map == null ? const <BuildingIssue>[] : checkBuilding(map);
    final problems = issues.where((i) => i.level == IssueLevel.problem).toList();
    final ready = map != null && problems.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(draft.name),
        actions: [
          IconButton(tooltip: 'Rename building', icon: const Icon(Icons.edit_outlined), onPressed: _rename),
          if (map != null)
            IconButton(
              tooltip: 'Share building',
              icon: const Icon(Icons.ios_share),
              onPressed: () => shareBuilding(context, widget.repository, widget.buildingId),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          _SetupSteps(
            hasFloors: draft.floors.isNotEmpty,
            hasPlaces: draft.nodes.isNotEmpty,
            ready: ready,
          ),
          const SizedBox(height: 16),
          Text('Floors', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (draft.floors.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Add a blueprint for each floor, starting with the ground floor. A photo of a printed plan works.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          for (final floor in draft.floors.reversed) ...[
            _FloorCard(
              floor: floor,
              image: _images(floor.image),
              places: draft.nodesOn(floor.level).length,
              markers: draft.nodesOn(floor.level).where((n) => n.marker != null).length,
              onOpen: () => _openFloor(floor.level),
              onRename: () => _renameFloor(floor),
              onReplace: () => _replaceDrawing(floor),
              onDelete: () => _deleteFloor(floor),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _addFloor,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(draft.floors.isEmpty ? 'Add the first floor' : 'Add a floor above'),
          ),
          const SizedBox(height: 24),
          Text('Checklist', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _IssuesCard(buildError: buildError, issues: issues),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: map == null || map.markerIds.isEmpty ? null : () => _openMarkers(map),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Print and place markers'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: map == null || map.markerIds.isEmpty ? null : _openWalk,
            icon: const Icon(Icons.directions_walk),
            label: const Text('Walk and check paths'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: ready ? () => _openNavigation(map) : null,
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Try navigation'),
          ),
        ],
      ),
    );
  }
}

class _SetupSteps extends StatelessWidget {
  const _SetupSteps({required this.hasFloors, required this.hasPlaces, required this.ready});

  final bool hasFloors;
  final bool hasPlaces;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(int n, String text, bool done) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: done ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
            child: done
                ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                : Text('$n', style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            step(1, 'Upload a blueprint for each floor', hasFloors),
            step(2, 'Tap to add rooms, lifts, stairs and entrances', hasPlaces),
            step(3, 'Swipe along the corridors on each floor', ready),
            step(4, 'Print the markers, stick them up, then walk and check', false),
          ],
        ),
      ),
    );
  }
}

class _FloorCard extends StatelessWidget {
  const _FloorCard({
    required this.floor,
    required this.image,
    required this.places,
    required this.markers,
    required this.onOpen,
    required this.onRename,
    required this.onReplace,
    required this.onDelete,
  });

  final DraftFloor floor;
  final ImageProvider image;
  final int places;
  final int markers;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 80,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(floor.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$places places · $markers markers${floor.metresPerPixel == null ? ' · scale not set' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Floor options',
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename();
                  case 'replace':
                    onReplace();
                  default:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'replace', child: Text('Replace blueprint')),
                PopupMenuItem(value: 'delete', child: Text('Delete floor')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IssuesCard extends StatelessWidget {
  const _IssuesCard({required this.buildError, required this.issues});

  final String? buildError;
  final List<BuildingIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    if (buildError != null) {
      rows.add(_row(context, Icons.error_outline, theme.colorScheme.error, _friendly(buildError!)));
    }
    for (final issue in issues.take(12)) {
      rows.add(
        _row(
          context,
          issue.level == IssueLevel.problem ? Icons.error_outline : Icons.info_outline,
          issue.level == IssueLevel.problem ? theme.colorScheme.error : theme.colorScheme.tertiary,
          issue.message,
        ),
      );
    }
    if (issues.length > 12) rows.add(Text('…and ${issues.length - 12} more'));
    if (rows.isEmpty) {
      rows.add(_row(context, Icons.check_circle_outline, theme.colorScheme.primary, 'Ready to navigate.'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      ),
    );
  }

  static String _friendly(String error) =>
      error.contains('"floors" must not be empty') ? 'Add at least one floor blueprint.' : error;

  Widget _row(BuildContext context, IconData icon, Color color, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
