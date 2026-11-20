import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/building_map.dart';
import '../scanner/marker_detector.dart';
import '../setup/building_editor_screen.dart';
import '../setup/share_actions.dart';
import '../storage/building_repository.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'blueprint_view.dart';
import 'navigation_screen.dart';

/// Home: the buildings on this phone, the bundled sample, and ways to add
/// more (set one up, or import a shared file).
class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.loadSample,
    this.createDetector = MarkerDetector.new,
  });

  final BuildingRepository repository;
  final AppSettings settings;

  /// Loads the bundled sample building, or throws [MapFormatException].
  final Future<BuildingMap> Function() loadSample;
  final FrameDetector Function() createDetector;

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  List<SavedBuilding>? _buildings;
  late final Future<BuildingMap> _sample = widget.loadSample();

  BuildingRepository get repo => widget.repository;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final list = await repo.list();
    if (mounted) setState(() => _buildings = list);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuildingEditorScreen(repository: repo, buildingId: id, createDetector: widget.createDetector),
      ),
    );
    await repo.removeUnusedImages(id).catchError((Object _) {});
    await _refresh();
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New building'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Building name', hintText: 'e.g. Main Block'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final id = await repo.create(name.trim().isEmpty ? 'New building' : name.trim());
    if (mounted) await _edit(id);
  }

  Future<void> _navigate(String id) async {
    try {
      final map = await repo.load(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NavigationScreen(
            map: map,
            images: folderFloorImages(repo.directoryOf(id)),
            createDetector: widget.createDetector,
          ),
        ),
      );
    } on MapFormatException catch (e) {
      if (!mounted) return;
      _toast('Finish setting up this building first: ${e.message}');
      await _edit(id);
    }
  }

  Future<void> _navigateSample(BuildingMap map) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NavigationScreen(map: map, images: assetFloorImages(), createDetector: widget.createDetector),
    ),
  );

  /// Copies the bundled sample into an editable building.
  Future<void> _copySample(BuildingMap sample) async {
    final id = await repo.create('${sample.name} (copy)');
    final json = Map<String, dynamic>.from(jsonDecode(jsonEncode(sample.toJson())) as Map);
    final floors = (json['floors'] as List<Object?>).cast<Map<String, dynamic>>();
    for (final floor in floors) {
      final asset = floor['image'] as String;
      final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
      floor['image'] = await repo.addImage(id, bytes, extension: asset.split('.').last);
    }
    await repo.writeJson(id, {...json, 'id': id, 'building': '${sample.name} (copy)'});
    await _refresh();
    if (mounted) await _edit(id);
  }

  Future<void> _import() async {
    final id = await importBuildingFile(context, repo);
    await _refresh();
    if (id != null && mounted) await _navigate(id);
  }

  Future<void> _delete(SavedBuilding building) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${building.name}?'),
        content: const Text('Its blueprints, places and markers are removed from this phone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok ?? false) {
      await repo.delete(building.id);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buildings = _buildings;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.explore_outlined), SizedBox(width: 10), Text(Brand.appName)],
        ),
        actions: [
          IconButton(tooltip: 'Import a building', icon: const Icon(Icons.file_download_outlined), onPressed: _import),
          ThemeModeButton(settings: widget.settings),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            Text('Find your way indoors', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Scan a marker on the wall, pick where you want to go, and follow the route across floors.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('Your buildings', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (buildings == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (buildings.isEmpty)
              _EmptyState(onCreate: _create, onImport: _import)
            else
              for (final b in buildings) ...[
                _BuildingCard(
                  title: b.name,
                  subtitle:
                      '${b.floorCount} ${b.floorCount == 1 ? 'floor' : 'floors'} · '
                      '${b.placeCount} ${b.placeCount == 1 ? 'place' : 'places'}',
                  onNavigate: () => _navigate(b.id),
                  onEdit: () => _edit(b.id),
                  onShare: () => shareBuilding(context, repo, b.id),
                  onDelete: () => _delete(b),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 16),
            Text('Sample', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<BuildingMap>(
              future: _sample,
              builder: (context, snapshot) {
                final map = snapshot.data;
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'The sample building could not be loaded: '
                        '${error is MapFormatException ? error.message : error}',
                      ),
                    ),
                  );
                }
                if (map == null) return const SizedBox(height: 80);
                return _BuildingCard(
                  title: map.name,
                  subtitle: '${map.floors.length} floors · ${map.nodes.length} places · try it out',
                  onNavigate: () => _navigateSample(map),
                  onEdit: () => _copySample(map),
                  editLabel: 'Copy to edit',
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('New building'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate, required this.onImport});

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.map_outlined, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Set up your first building', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Upload a blueprint for each floor, tap to mark rooms, lifts and stairs, then print the markers '
              'the app makes and stick them up. Or import a building someone shared with you.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('New building')),
                OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.title,
    required this.subtitle,
    required this.onNavigate,
    required this.onEdit,
    this.onShare,
    this.onDelete,
    this.editLabel = 'Edit',
  });

  final String title;
  final String subtitle;
  final VoidCallback onNavigate;
  final VoidCallback onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: const Icon(Icons.apartment),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (onShare != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    onSelected: (value) {
                      if (value == 'share') onShare?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      if (onShare != null) const PopupMenuItem(value: 'share', child: Text('Share building file')),
                      if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Navigate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: Text(editLabel),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
