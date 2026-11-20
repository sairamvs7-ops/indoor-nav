import 'package:flutter/material.dart';

import '../map/building_map.dart';
import '../scanner/marker_detector.dart';
import '../scanner/scanner_screen.dart';
import 'building_draft.dart';
import 'walk_check.dart';

/// Checking the paths by walking: scan each marker as you pass it, and every
/// pair of scans in a row is compared with the routes the map knows. Missing
/// connections (including lifts and stairs between floors) are added for you.
class WalkRecorderScreen extends StatefulWidget {
  const WalkRecorderScreen({super.key, required this.draft, this.createDetector = MarkerDetector.new});

  final BuildingDraft draft;
  final FrameDetector Function() createDetector;

  @override
  State<WalkRecorderScreen> createState() => _WalkRecorderScreenState();
}

class _WalkRecorderScreenState extends State<WalkRecorderScreen> {
  final List<int> _scanned = [];
  final List<WalkFinding> _findings = [];
  final Set<int> _linked = {}; // indexes into _findings whose link was added

  BuildingDraft get draft => widget.draft;

  BuildingMap? get _map => draft.tryBuild().$1;

  Future<void> _scan() async {
    final map = _map;
    if (map == null) return;
    final markerId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(isKnownMarker: map.isKnownMarker, createDetector: widget.createDetector),
      ),
    );
    if (markerId == null || !mounted) return;
    final place = map.nodeForMarker(markerId);
    if (place == null) return;
    final previous = _scanned.isEmpty ? null : _scanned.last;
    if (previous == place.id) return;
    setState(() => _scanned.add(place.id));
    if (previous == null) return;

    final finding = checkWalkStep(map, previous, place.id);
    setState(() => _findings.add(finding));
    // A way the map didn't have at all is certain: add it straight away.
    if (finding.verdict == WalkVerdict.missing || finding.verdict == WalkVerdict.unlinkedFloors) {
      _addLink(_findings.length - 1);
    }
  }

  void _addLink(int index) {
    final finding = _findings[index];
    draft.addPaths([(finding.from.id, finding.to.id)]);
    setState(() => _linked.add(index));
  }

  void _undoLast() {
    if (_scanned.isEmpty) return;
    setState(() {
      _scanned.removeLast();
      if (_findings.length >= _scanned.length && _findings.isNotEmpty) {
        _linked.remove(_findings.length - 1);
        _findings.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final map = _map;
    final remaining = map == null ? const <MapNode>[] : notVisited(map, _scanned.toSet());
    final total = map?.markerIds.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk and check'),
        actions: [
          IconButton(
            tooltip: 'Undo last scan',
            onPressed: _scanned.isEmpty ? null : _undoLast,
            icon: const Icon(Icons.undo),
          ),
        ],
      ),
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
                  Text('Walk the building with the markers up', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan every marker you pass, in order, including the lifts and stairs you use. '
                    'Each walk between two scans is checked against the map, and missing ways are added.',
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: total == 0 ? 0 : (total - remaining.length) / total),
                  const SizedBox(height: 6),
                  Text('${total - remaining.length} of $total marked places visited'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_scanned.length == 1)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('Started at ${map?.nodes[_scanned.first]?.name ?? 'a marker'}'),
              subtitle: const Text('Walk to the next marker and scan it.'),
            ),
          for (final (i, finding) in _findings.indexed.toList().reversed) _FindingTile(
            finding: finding,
            linked: _linked.contains(i),
            onAddLink: () => _addLink(i),
          ),
          if (remaining.isNotEmpty && _scanned.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text('Not visited yet (${remaining.length})'),
              children: [
                for (final n in remaining)
                  ListTile(
                    dense: true,
                    title: Text(n.name),
                    subtitle: Text('Marker ${n.markerId} · ${map!.floor(n.floor).name}'),
                  ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: map == null ? null : _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(_scanned.isEmpty ? 'Scan first marker' : 'Scan next marker'),
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding, required this.linked, required this.onAddLink});

  final WalkFinding finding;
  final bool linked;
  final VoidCallback onAddLink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (finding.verdict) {
      WalkVerdict.confirmed || WalkVerdict.linkedFloors => (Icons.check_circle, scheme.primary),
      WalkVerdict.missing || WalkVerdict.unlinkedFloors => (Icons.add_link, scheme.secondary),
      WalkVerdict.viaOthers => (Icons.alt_route, scheme.tertiary),
      WalkVerdict.floorChangeUnknown => (Icons.help_outline, scheme.error),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(finding.message),
        subtitle: linked ? const Text('Link added to the map') : null,
        trailing: finding.verdict == WalkVerdict.viaOthers && !linked
            ? TextButton(onPressed: onAddLink, child: const Text('Add link'))
            : null,
      ),
    );
  }
}
