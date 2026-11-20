import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../map/aruco_markers.dart';
import '../map/building_map.dart';
import '../ui/app_theme.dart';
import '../mapgen/floor_map_generator.dart' show GapClosing;
import '../mapgen/generate_regions.dart';
import '../ui/blueprint_view.dart';
import '../ui/generated_map_painter.dart';
import '../ui/node_style.dart';
import 'building_draft.dart';
import 'region_form.dart';

enum EditMode { map, places, corridors, scale }

/// What a touch does in corridors mode.
enum CorridorTool { draw, pan, erase, link }

/// Setting up one floor: the app generates a map from the blueprint, then
/// you say what each area is, add any extra places and paths, and set the
/// real-world scale.
class FloorEditorScreen extends StatefulWidget {
  const FloorEditorScreen({
    super.key,
    required this.draft,
    required this.level,
    required this.images,
    required this.loadImage,
  });

  final BuildingDraft draft;
  final int level;
  final FloorImages images;

  /// Reads a floor's blueprint file, for generating its map.
  final Future<Uint8List> Function(String image) loadImage;

  @override
  State<FloorEditorScreen> createState() => _FloorEditorScreenState();
}

class _FloorEditorScreenState extends State<FloorEditorScreen> {
  EditMode _mode = EditMode.map;
  bool _guide = false; // show the blueprint faintly under the generated map
  bool _generating = false;
  String? _region; // map mode: the area just tapped
  List<Offset>? _trace; // map mode: corners of an area being traced
  GapClosing _gaps = GapClosing.normal;
  CorridorTool _tool = CorridorTool.draw;
  List<Offset>? _stroke; // corridor being drawn right now
  BuildingMap? _preview; // the built network, to show how places join corridors
  final TransformationController _view = TransformationController();
  int? _selected; // link tool: the place a new path starts from
  int? _moving; // places mode: the place waiting for its new spot
  List<(int, int)>? _suggestions;
  final List<Offset> _scalePoints = [];

  BuildingDraft get draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _preview = draft.tryBuild().$1;
    draft.addListener(_redraw);
    // A new floor gets its map generated straight away.
    if (draft.floor(widget.level).regions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_generate()));
    }
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final floor = draft.floor(widget.level);
      final regions = await generateRegions(await widget.loadImage(floor.image), gaps: _gaps);
      if (!mounted) return;
      draft.setGeneratedMap(widget.level, regions);
      final rooms = regions.where((r) => r.kind == RegionKind.room).length;
      final corridors = regions.where((r) => r.kind == RegionKind.corridor).length;
      _toast(
        regions.isEmpty
            ? 'No rooms found. Try "Wider doorways", or trace the areas yourself.'
            : 'Found $rooms rooms and $corridors corridors. Tap each area to say what it is.',
      );
    } on FormatException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _regenerate() async {
    final gaps = await showModalBottomSheet<GapClosing>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Generate the map again'),
              subtitle: Text('Places you have named stay, linked to the area they sit in.'),
            ),
            for (final (option, title, subtitle) in const [
              (GapClosing.narrow, 'Narrow doorways', 'Keeps small rooms apart'),
              (GapClosing.normal, 'Normal', 'Works for most plans'),
              (GapClosing.wide, 'Wider doorways', 'When rooms leak into each other'),
            ])
              ListTile(
                leading: Icon(option == _gaps ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(title),
                subtitle: Text(subtitle),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (gaps == null) return;
    _gaps = gaps;
    await _generate();
  }

  Future<void> _openRegion(FloorRegion region) async {
    setState(() => _region = region.id);
    final result = await showRegionForm(context, draft: draft, region: region);
    if (mounted) setState(() => _region = null);
    if (result == null) return;
    if (result.delete) {
      draft.removeRegion(widget.level, region.id);
      return;
    }
    switch (result.kind) {
      case RegionKind.corridor || RegionKind.ignored:
        draft.setRegionKind(widget.level, region.id, result.kind);
      case RegionKind.room || RegionKind.stairs || RegionKind.lift:
        draft.assignPlace(
          widget.level,
          region.id,
          name: result.name,
          type: result.type,
          withMarker: result.hasMarker,
          marker: result.marker,
          link: result.link,
        );
    }
  }

  Future<void> _finishTrace() async {
    final trace = _trace;
    setState(() => _trace = null);
    if (trace == null || trace.length < 3) return;
    final id = draft.addRegion(widget.level, [for (final p in trace) (x: p.dx, y: p.dy)]);
    final region = draft.floor(widget.level).region(id);
    if (region != null) await _openRegion(region);
  }

  @override
  void dispose() {
    draft.removeListener(_redraw);
    _view.dispose();
    super.dispose();
  }

  void _redraw() => setState(() => _preview = draft.tryBuild().$1);

  void _setTool(CorridorTool tool) => setState(() {
    _tool = tool;
    _selected = null;
    _suggestions = null;
  });

  void _drawStart(Offset p) => setState(() => _stroke = [p]);

  void _drawUpdate(Offset p) {
    final stroke = _stroke;
    if (stroke == null) return;
    // Skip points closer than ~2 screen pixels; the stroke is smoothed later.
    if ((stroke.last - p).distance * _screenScale < 2) return;
    setState(() => stroke.add(p));
  }

  void _drawEnd() {
    final stroke = _stroke;
    setState(() => _stroke = null);
    if (stroke == null) return;
    final added = draft.addCorridor(widget.level, [for (final p in stroke) (x: p.dx, y: p.dy)]);
    if (!added) _toast('Too short. Swipe along the whole corridor.');
  }

  /// Drawing-to-screen scale, including pinch zoom.
  double _screenScale = 1;

  void _setMode(EditMode mode) => setState(() {
    _mode = mode;
    _trace = null;
    _region = null;
    _selected = null;
    _moving = null;
    _suggestions = null;
    _scalePoints.clear();
  });

  DraftNode? _nodeAt(Offset point, double scale) {
    DraftNode? nearest;
    var best = 26 / scale;
    for (final node in draft.nodesOn(widget.level)) {
      final d = (Offset(node.x, node.y) - point).distance;
      if (d <= best) {
        nearest = node;
        best = d;
      }
    }
    return nearest;
  }

  Future<void> _onTap(Offset point, double scale) async {
    switch (_mode) {
      case EditMode.map when _trace != null:
        final trace = _trace!;
        // Tapping near the first corner closes the shape.
        if (trace.length >= 3 && (trace.first - point).distance * scale < 24) {
          await _finishTrace();
        } else {
          setState(() => trace.add(point));
        }
      case EditMode.map:
        final region = draft.regionAt(widget.level, (x: point.dx, y: point.dy));
        if (region == null) {
          _toast(draft.floor(widget.level).regions.isEmpty ? 'Generate the map first.' : 'Nothing here. Use Trace to add an area.');
        } else {
          await _openRegion(region);
        }
      case EditMode.places:
        final moving = _moving;
        if (moving != null) {
          draft.moveNode(moving, point.dx, point.dy);
          setState(() => _moving = null);
          return;
        }
        final node = _nodeAt(point, scale);
        if (node == null) {
          await _addPlace(point);
        } else {
          await _editPlace(node);
        }
      case EditMode.corridors when _tool == CorridorTool.erase:
        final index = draft.corridorNear(widget.level, (x: point.dx, y: point.dy), 24 / scale);
        if (index == null) {
          _toast('Tap on a corridor line to erase it');
        } else {
          draft.removeCorridor(index);
          _toast('Corridor erased');
        }
      case EditMode.corridors when _tool != CorridorTool.link:
        return;
      case EditMode.corridors:
        final node = _nodeAt(point, scale);
        final selected = _selected;
        if (node == null || node.id == selected) {
          setState(() => _selected = null);
        } else if (selected == null) {
          setState(() => _selected = node.id);
        } else {
          final added = draft.togglePath(selected, node.id);
          _toast(added ? 'Path added' : 'Path removed');
          // Keep going from the place just reached, so a corridor can be
          // drawn with one tap per place.
          setState(() => _selected = node.id);
        }
      case EditMode.scale:
        setState(() => _scalePoints.add(point));
        if (_scalePoints.length == 2) await _askDistance();
    }
  }

  Future<void> _addPlace(Offset point) async {
    final result = await showPlaceForm(context, draft: draft);
    if (result == null) return;
    draft.addNode(
      name: result.name,
      type: result.type,
      floor: widget.level,
      x: point.dx,
      y: point.dy,
      withMarker: result.hasMarker,
      link: result.link,
    );
  }

  Future<void> _editPlace(DraftNode node) async {
    final result = await showPlaceForm(context, draft: draft, existing: node);
    if (result == null) return;
    switch (result.action) {
      case PlaceAction.delete:
        draft.deleteNode(node.id);
      case PlaceAction.move:
        setState(() => _moving = node.id);
      case PlaceAction.save:
        draft.updateNode(
          node.id,
          name: result.name,
          type: result.type,
          link: result.link ?? '',
          clearMarker: !result.hasMarker,
          marker: result.hasMarker ? (result.marker ?? node.marker ?? draft.nextFreeMarker()) : null,
        );
    }
  }

  Future<void> _askDistance() async {
    final pixels = (_scalePoints[0] - _scalePoints[1]).distance;
    final controller = TextEditingController();
    final metres = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How far apart are these points?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'metres', hintText: 'e.g. 12.5'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('Set scale'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (metres != null && metres > 0 && pixels > 0) {
      draft.calibrateFloor(widget.level, pixels: pixels, metres: metres);
      _toast('Scale set: 1 m ≈ ${(pixels / metres).toStringAsFixed(1)} px');
    }
    setState(_scalePoints.clear);
  }

  void _suggest() {
    final suggestions = draft.suggestionsFor(widget.level);
    setState(() => _suggestions = suggestions);
    if (suggestions.isEmpty) _toast('No new paths to suggest');
  }

  void _acceptSuggestions() {
    final suggestions = _suggestions ?? const [];
    draft.addPaths(suggestions);
    setState(() => _suggestions = null);
    _toast('Added ${suggestions.length} paths. Tap two places to remove any that cross a wall.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  String get _help => switch (_mode) {
    EditMode.map when _generating => 'Reading the blueprint and drawing the map…',
    EditMode.map when _trace != null =>
      'Tap each corner of the area. Tap the first corner again, or Done, to finish (${_trace!.length} corners).',
    EditMode.map => 'Tap each area to name the room, or mark it as corridor, stairs, lift or not used.',
    EditMode.places when _moving != null => 'Tap the new spot for ${draft.nodes[_moving]?.name}.',
    EditMode.places => 'Tap an empty spot to add a room, lift, stairs or entrance. Tap a place to edit it.',
    EditMode.corridors => switch (_tool) {
      CorridorTool.draw => 'Swipe along each corridor, end to end. Rooms join the nearest corridor by themselves.',
      CorridorTool.pan => 'Pinch to zoom and drag to move around the blueprint.',
      CorridorTool.erase => 'Tap a corridor line to erase it.',
      CorridorTool.link when _selected != null =>
        'From ${draft.nodes[_selected]?.name}: tap a place to link or unlink it. Tap it again to stop.',
      CorridorTool.link => 'Link two places directly, for a door or passage no corridor covers.',
    },
    EditMode.scale when _scalePoints.length == 1 => 'Now tap the second point.',
    EditMode.scale => 'Tap two points whose real distance you know, like the ends of a corridor.',
  };

  @override
  Widget build(BuildContext context) {
    final floor = draft.floor(widget.level);
    final theme = Theme.of(context);
    final colors = MapColors.resolve(context);
    final placeCount = draft.nodesOn(widget.level).length;
    final corridorCount = draft.corridorsOn(widget.level).length;
    final drawing = _mode == EditMode.corridors && _tool == CorridorTool.draw;
    final hasMap = floor.regions.isNotEmpty;
    final style = MapStyle.of(theme.brightness);
    final names = {
      for (final n in draft.nodesOn(widget.level))
        if (n.region != null) n.region!: n.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(floor.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<EditMode>(
              style: SegmentedButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                selectedBackgroundColor: theme.colorScheme.secondaryContainer,
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: EditMode.map, icon: Icon(Icons.map_outlined), label: Text('Map')),
                ButtonSegment(value: EditMode.places, icon: Icon(Icons.add_location_alt_outlined), label: Text('Places')),
                ButtonSegment(value: EditMode.corridors, icon: Icon(Icons.route), label: Text('Paths')),
                ButtonSegment(value: EditMode.scale, icon: Icon(Icons.straighten), label: Text('Scale')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _setMode(s.first),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Material(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined, color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_help, style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: BlueprintView(
                    transformationController: _view,
                    interactive: !drawing,
                    onDrawStart: drawing ? _drawStart : null,
                    onDrawUpdate: drawing ? _drawUpdate : null,
                    onDrawEnd: drawing ? _drawEnd : null,
                    image: widget.images(floor.image),
                    // Once a map is generated the blueprint is only a faint guide.
                    imageOpacity: hasMap ? (_guide ? 0.3 : 0) : 1,
                    underlay: hasMap
                        ? (_) => GeneratedMapPainter(
                            regions: List.of(floor.regions),
                            drawingWidth: floor.width,
                            style: style,
                            names: names,
                            selectedRegion: _region,
                            showIgnored: _mode == EditMode.map,
                          )
                        : null,
                    imageWidth: floor.width,
                    imageHeight: floor.height,
                    label: '${floor.name} blueprint',
                    onTap: (point, scale) => _onTap(point, scale),
                    overlay: (scale) => _EditorPainter(
                      draft: draft,
                      preview: _preview,
                      stroke: _stroke,
                      screenScale: (s) => _screenScale = s * _view.value.getMaxScaleOnAxis(),
                      level: widget.level,
                      colors: colors,
                      selected: _selected ?? _moving,
                      suggestions: _suggestions ?? const [],
                      scalePoints: List.of(_scalePoints),
                      trace: _trace == null ? null : List.of(_trace!),
                      scale: scale,
                      revision: Object.hash(placeCount, corridorCount, _selected, _moving, _suggestions, _scalePoints.length),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: switch (_mode) {
                EditMode.map when _generating => const LinearProgressIndicator(),
                EditMode.map when _trace != null => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => setState(() => _trace = null), child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: (_trace?.length ?? 0) >= 3 ? _finishTrace : null,
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
                EditMode.map when !hasMap => FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate map from blueprint'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                EditMode.map => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _trace = []),
                        icon: const Icon(Icons.polyline_outlined),
                        label: const Text('Trace area'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: _guide ? 'Hide blueprint' : 'Show blueprint underneath',
                      isSelected: _guide,
                      onPressed: () => setState(() => _guide = !_guide),
                      icon: const Icon(Icons.layers_outlined),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Generate again',
                      onPressed: _regenerate,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                EditMode.corridors when _tool == CorridorTool.link && (_suggestions?.isNotEmpty ?? false) => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _suggestions = null),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _acceptSuggestions,
                        icon: const Icon(Icons.done_all),
                        label: Text('Add ${_suggestions!.length} suggested'),
                      ),
                    ),
                  ],
                ),
                EditMode.corridors => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<CorridorTool>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: CorridorTool.draw, icon: Icon(Icons.gesture), tooltip: 'Draw'),
                              ButtonSegment(
                                value: CorridorTool.pan,
                                icon: Icon(Icons.pan_tool_outlined),
                                tooltip: 'Move map',
                              ),
                              ButtonSegment(
                                value: CorridorTool.erase,
                                icon: Icon(Icons.backspace_outlined),
                                tooltip: 'Erase',
                              ),
                              ButtonSegment(value: CorridorTool.link, icon: Icon(Icons.link), tooltip: 'Link places'),
                            ],
                            selected: {_tool},
                            onSelectionChanged: (s) => _setTool(s.first),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Undo last corridor',
                          onPressed: corridorCount == 0 ? null : () => draft.undoCorridor(widget.level),
                          icon: const Icon(Icons.undo),
                        ),
                      ],
                    ),
                    if (_tool == CorridorTool.link) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: placeCount < 2 ? null : _suggest,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Suggest direct links'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$corridorCount corridors · $placeCount places',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                EditMode.scale => Text(
                  floor.metresPerPixel == null
                      ? 'Scale not set: distances are estimated.'
                      : 'Scale: 1 m ≈ ${(1 / floor.metresPerPixel!).toStringAsFixed(1)} px on this drawing',
                  style: theme.textTheme.bodyMedium,
                ),
                EditMode.places => Text(
                  '$placeCount places · $corridorCount corridors · pinch to zoom',
                  style: theme.textTheme.bodyMedium,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.draft,
    required this.preview,
    required this.stroke,
    required this.screenScale,
    required this.level,
    required this.colors,
    required this.selected,
    required this.suggestions,
    required this.scalePoints,
    this.trace,
    required this.scale,
    required this.revision,
  });

  final BuildingDraft draft;
  final BuildingMap? preview;
  final List<Offset>? stroke;
  final void Function(double scale) screenScale;
  final int level;
  final MapColors colors;
  final int? selected;
  final List<(int, int)> suggestions;
  final List<Offset> scalePoints;

  /// Corners of an area being traced, in drawing pixels.
  final List<Offset>? trace;
  final double scale;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    screenScale(scale);
    Offset at(DraftNode n) => Offset(n.x * scale, n.y * scale);
    Offset pt(Pt p) => Offset(p.x * scale, p.y * scale);

    // Corridors: a wide translucent band with a centre line.
    final band = Paint()
      ..color = colors.path.withValues(alpha: 0.22)
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final centre = Paint()
      ..color = colors.path
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final (_, corridor) in draft.corridorsOn(level)) {
      final path = Path()..moveTo(pt(corridor.points.first).dx, pt(corridor.points.first).dy);
      for (final p in corridor.points.skip(1)) {
        path.lineTo(pt(p).dx, pt(p).dy);
      }
      canvas
        ..drawPath(path, band)
        ..drawPath(path, centre);
    }

    // How each place joins its corridor (worked out automatically).
    final map = preview;
    if (map != null) {
      final join = Paint()
        ..color = colors.suggestion
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (final e in map.edges) {
        if (!e.automatic || e.kind != EdgeKind.walk) continue;
        final a = map.nodes[e.from]!;
        final b = map.nodes[e.to]!;
        if (a.floor != level || a.automatic == b.automatic) continue;
        _dashedLine(canvas, Offset(a.x * scale, a.y * scale), Offset(b.x * scale, b.y * scale), join);
      }
    }

    // The corridor being drawn right now.
    final live = stroke;
    if (live != null && live.length > 1) {
      final path = Path()..moveTo(live.first.dx * scale, live.first.dy * scale);
      for (final p in live.skip(1)) {
        path.lineTo(p.dx * scale, p.dy * scale);
      }
      canvas
        ..drawPath(path, band..color = colors.selected.withValues(alpha: 0.3))
        ..drawPath(path, centre..color = colors.selected);
    }

    final pathCasing = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final pathPaint = Paint()
      ..color = colors.path
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in draft.edgesOn(level)) {
      canvas
        ..drawLine(at(draft.nodes[a]!), at(draft.nodes[b]!), pathCasing)
        ..drawLine(at(draft.nodes[a]!), at(draft.nodes[b]!), pathPaint);
    }

    final dash = Paint()
      ..color = colors.suggestion
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in suggestions) {
      _dashedLine(canvas, at(draft.nodes[a]!), at(draft.nodes[b]!), dash);
    }

    for (final node in draft.nodesOn(level)) {
      final c = at(node);
      final isSelected = node.id == selected;
      if (node.type == NodeType.corridor) {
        canvas
          ..drawCircle(c, 6, Paint()..color = Colors.white)
          ..drawCircle(c, 4, Paint()..color = isSelected ? colors.selected : colors.path);
        continue;
      }
      if (isSelected) canvas.drawCircle(c, 19, Paint()..color = colors.selected.withValues(alpha: 0.45));
      canvas
        ..drawCircle(c, 13, Paint()..color = Colors.white)
        ..drawCircle(c, 11, Paint()..color = node.type.isVertical ? colors.connector : colors.place);
      _text(
        canvas,
        node.marker?.toString() ?? '–',
        c,
        TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: node.type.isVertical ? Colors.black : Colors.white,
        ),
      );
      _text(
        canvas,
        node.name,
        c + const Offset(0, 21),
        const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          backgroundColor: Color(0xCCFFFFFF),
        ),
      );
    }

    final corners = trace;
    if (corners != null && corners.isNotEmpty) {
      final line = Paint()
        ..color = colors.selected
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(corners.first.dx * scale, corners.first.dy * scale);
      for (final c in corners.skip(1)) {
        path.lineTo(c.dx * scale, c.dy * scale);
      }
      canvas.drawPath(path, line);
      for (final (i, c) in corners.indexed) {
        canvas
          ..drawCircle(c * scale, i == 0 ? 9 : 6, Paint()..color = Colors.white)
          ..drawCircle(c * scale, i == 0 ? 7 : 4.5, Paint()..color = colors.selected);
      }
    }

    if (scalePoints.isNotEmpty) {
      final p = Paint()
        ..color = colors.selected
        ..strokeWidth = 3;
      final points = [for (final s in scalePoints) s * scale];
      for (final point in points) {
        canvas.drawCircle(point, 7, p);
      }
      if (points.length == 2) canvas.drawLine(points[0], points[1], p);
    }
  }

  void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 120);
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final length = (b - a).distance;
    if (length == 0) return;
    final direction = (b - a) / length;
    for (var t = 0.0; t < length; t += 12) {
      canvas.drawLine(a + direction * t, a + direction * math.min(t + 7, length), paint);
    }
  }

  @override
  bool shouldRepaint(_EditorPainter old) => true;
}

enum PlaceAction { save, move, delete }

class PlaceFormResult {
  const PlaceFormResult({
    required this.action,
    required this.name,
    required this.type,
    required this.hasMarker,
    this.marker,
    this.link,
  });

  final PlaceAction action;
  final String name;
  final NodeType type;
  final bool hasMarker;
  final int? marker;
  final String? link;
}

/// The add/edit sheet for a place. Resolves to null if dismissed.
Future<PlaceFormResult?> showPlaceForm(BuildContext context, {required BuildingDraft draft, DraftNode? existing}) {
  return showModalBottomSheet<PlaceFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _PlaceForm(draft: draft, existing: existing),
    ),
  );
}

class _PlaceForm extends StatefulWidget {
  const _PlaceForm({required this.draft, this.existing});

  final BuildingDraft draft;
  final DraftNode? existing;

  @override
  State<_PlaceForm> createState() => _PlaceFormState();
}

class _PlaceFormState extends State<_PlaceForm> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _link = TextEditingController(text: widget.existing?.link ?? '');
  late final TextEditingController _marker = TextEditingController(
    text: (widget.existing?.marker ?? widget.draft.nextFreeMarker())?.toString() ?? '',
  );
  late NodeType _type = widget.existing?.type ?? NodeType.room;
  late bool _hasMarker = widget.existing == null || widget.existing!.marker != null;
  String? _markerError;

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    _marker.dispose();
    super.dispose();
  }

  void _submit(PlaceAction action) {
    int? marker;
    if (_hasMarker && _type != NodeType.corridor) {
      marker = int.tryParse(_marker.text.trim());
      if (marker == null || marker < 0 || marker >= markerCount) {
        setState(() => _markerError = 'Use a number from 0 to ${markerCount - 1}');
        return;
      }
    }
    Navigator.of(context).pop(
      PlaceFormResult(
        action: action,
        name: _name.text,
        type: _type,
        hasMarker: _hasMarker && _type != NodeType.corridor,
        marker: marker,
        link: _type.isVertical ? _link.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = widget.existing;
    final markerOwner = () {
      final value = int.tryParse(_marker.text.trim());
      if (value == null) return null;
      for (final n in widget.draft.nodes.values) {
        if (n.marker == value && n.id != existing?.id) return n;
      }
      return null;
    }();
    final linkNames = _type.isVertical ? widget.draft.linkNames(_type) : const <String>[];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add a place' : 'Edit ${existing.name}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in NodeType.values)
                  ChoiceChip(
                    avatar: Icon(iconFor(type), size: 18),
                    label: Text(type.label),
                    selected: _type == type,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: switch (_type) {
                  NodeType.room => 'e.g. Room 101, Library',
                  NodeType.lift => 'e.g. Lift A',
                  NodeType.stairs => 'e.g. Main stairs',
                  NodeType.corridor => 'Optional',
                  _ => 'e.g. ${_type.label}',
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
                  helperText: 'Use the same link name on every floor this lift or staircase reaches.',
                  helperMaxLines: 2,
                ),
              ),
              if (linkNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final name in linkNames)
                      ActionChip(label: Text(name), onPressed: () => setState(() => _link.text = name)),
                  ],
                ),
              ],
            ],
            if (_type != NodeType.corridor) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Has a marker on the wall'),
                subtitle: const Text('People scan it to find where they are'),
                value: _hasMarker,
                onChanged: (v) => setState(() => _hasMarker = v),
              ),
              if (_hasMarker)
                TextField(
                  controller: _marker,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _markerError = null),
                  decoration: InputDecoration(
                    labelText: 'Marker number',
                    errorText: _markerError,
                    helperText: markerOwner == null
                        ? null
                        : 'In use by ${markerOwner.name}; the two will swap markers.',
                  ),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Corridor points have no marker. Use them to shape routes around corners.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _submit(PlaceAction.save),
              child: Text(existing == null ? 'Add place' : 'Save'),
            ),
            if (existing != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _submit(PlaceAction.move),
                      icon: const Icon(Icons.open_with),
                      label: const Text('Move'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      onPressed: () => Navigator.of(context).pop(
                        PlaceFormResult(action: PlaceAction.delete, name: '', type: _type, hasMarker: false),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
