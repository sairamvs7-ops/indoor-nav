import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/building_map.dart';
import 'package:indoor_nav_mobile/setup/building_checks.dart';
import 'package:indoor_nav_mobile/setup/building_draft.dart';
import 'package:indoor_nav_mobile/setup/path_suggester.dart';
import 'package:indoor_nav_mobile/storage/building_repository.dart';

/// A draft whose saves are recorded instead of written to disk.
(BuildingDraft, List<Map<String, dynamic>>) newDraft() {
  final saved = <Map<String, dynamic>>[];
  final draft = BuildingDraft.fromJson(
    emptyBuildingJson(id: 'abcdef0123456789', name: 'Block A'),
    save: (json) async => saved.add(json),
    saveDelay: Duration.zero,
  );
  return (draft, saved);
}

void main() {
  group('suggestPaths', () {
    test('links places along a corridor without skipping over one', () {
      final points = [const PathPoint(1, 0, 0), const PathPoint(2, 10, 0), const PathPoint(3, 20, 0)];

      expect(suggestPaths(points), [(1, 2), (2, 3)]);
    });

    test('links the sides of a square, not its diagonals', () {
      final points = [
        const PathPoint(1, 0, 0),
        const PathPoint(2, 10, 0),
        const PathPoint(3, 10, 10),
        const PathPoint(4, 0, 10),
      ];

      expect(suggestPaths(points).toSet(), {(1, 2), (2, 3), (3, 4), (1, 4)});
    });

    test('skips paths that already exist and keeps far places reachable', () {
      final points = [const PathPoint(5, 0, 0), const PathPoint(2, 10, 0), const PathPoint(9, 500, 0)];

      expect(suggestPaths(points, existing: {(2, 5)}), [(2, 9)]);
    });
  });

  group('BuildingDraft', () {
    test('adds floors upwards and places with the next free marker', () {
      final (draft, _) = newDraft();

      expect(draft.addFloor(name: 'Ground', image: 'g.jpg', width: 200, height: 100), 0);
      expect(draft.addFloor(name: 'First', image: 'f.jpg', width: 200, height: 100), 1);
      final a = draft.addNode(name: 'Room 1', type: NodeType.room, floor: 0, x: 10, y: 10);
      final b = draft.addNode(name: '', type: NodeType.corridor, floor: 0, x: 50, y: 10);
      final c = draft.addNode(name: 'Lift', type: NodeType.lift, floor: 0, x: 900, y: -5, link: ' Lift A ');

      expect(draft.nodes[a]!.marker, 1);
      expect(draft.nodes[b]!.marker, isNull);
      expect(draft.nodes[b]!.name, 'Corridor point 2');
      expect(draft.nodes[c]!.marker, 2);
      expect(draft.nodes[c]!.link, 'Lift A');
      expect((draft.nodes[c]!.x, draft.nodes[c]!.y), (200.0, 0.0)); // kept on the drawing
    });

    test('giving a place a marker that is in use swaps the two markers', () {
      final (draft, _) = newDraft();
      draft.addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100);
      final a = draft.addNode(name: 'A', type: NodeType.room, floor: 0, x: 0, y: 0);
      final b = draft.addNode(name: 'B', type: NodeType.room, floor: 0, x: 10, y: 0);

      draft.updateNode(b, marker: 1);

      expect(draft.nodes[a]!.marker, 2);
      expect(draft.nodes[b]!.marker, 1);
      draft.updateNode(a, clearMarker: true);
      expect(draft.nodes[a]!.marker, isNull);
      expect(draft.nextFreeMarker(), 2);
    });

    test('toggles paths, and deleting a place or floor removes its paths', () {
      final (draft, _) = newDraft();
      draft
        ..addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100)
        ..addFloor(name: 'First', image: 'f.jpg', width: 100, height: 100);
      final a = draft.addNode(name: 'A', type: NodeType.room, floor: 0, x: 0, y: 0);
      final b = draft.addNode(name: 'B', type: NodeType.room, floor: 0, x: 10, y: 0);
      final c = draft.addNode(name: 'C', type: NodeType.room, floor: 1, x: 10, y: 0);

      expect(draft.togglePath(a, b), isTrue);
      expect(draft.isConnected(b, a), isTrue);
      expect(draft.togglePath(b, a), isFalse);
      draft.addPaths([(a, b), (b, a)]);
      expect(draft.edges, hasLength(1));

      draft.deleteNode(b);
      expect(draft.edges, isEmpty);
      draft.removeFloor(1);
      expect(draft.nodes.containsKey(c), isFalse);
      expect(draft.floors.map((f) => f.level), [0]);
    });

    test('replacing a drawing keeps places in the same relative spot', () {
      final (draft, _) = newDraft();
      draft.addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 50);
      final a = draft.addNode(name: 'A', type: NodeType.room, floor: 0, x: 50, y: 25);
      draft.calibrateFloor(0, pixels: 10, metres: 5);

      draft.replaceFloorImage(0, image: 'g2.jpg', width: 400, height: 200);

      expect((draft.nodes[a]!.x, draft.nodes[a]!.y), (200.0, 100.0));
      expect(draft.floor(0).metresPerPixel, 0.125);
      expect(draft.floor(0).image, 'g2.jpg');
    });

    test('builds a valid map with suggested paths and saves every change', () async {
      final (draft, saved) = newDraft();
      draft.addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100);
      draft.addNode(name: 'A', type: NodeType.entry, floor: 0, x: 0, y: 0);
      draft.addNode(name: 'B', type: NodeType.room, floor: 0, x: 50, y: 0);
      draft.addPaths(draft.suggestionsFor(0));

      final (map, error) = draft.tryBuild();

      expect(error, isNull);
      expect(map!.edges, hasLength(1));
      await draft.flush();
      await Future<void>.delayed(Duration.zero);
      expect(saved.last['nodes'], hasLength(2));
    });

    test('swiped corridors: smoothed, too-short swipes ignored, undo and erase', () {
      final (draft, _) = newDraft();
      draft.addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100);
      final room = draft.addNode(name: 'Lab', type: NodeType.room, floor: 0, x: 50, y: 40);

      expect(draft.addCorridor(0, [(x: 10.0, y: 50.0), (x: 10.5, y: 50.0)]), isFalse);
      expect(draft.addCorridor(0, [(x: 0.0, y: 50.0), (x: 50.0, y: 50.2), (x: 100.0, y: 50.0)]), isTrue);
      expect(draft.corridors.single.points, hasLength(2)); // wobble removed

      final (map, error) = draft.tryBuild();
      expect(error, isNull);
      expect(map!.graph[room], hasLength(1)); // joined to the corridor

      expect(draft.corridorNear(0, (x: 70.0, y: 52.0), 5), 0);
      expect(draft.corridorNear(0, (x: 70.0, y: 80.0), 5), isNull);
      draft.addCorridor(0, [(x: 50.0, y: 0.0), (x: 50.0, y: 100.0)]);
      expect(draft.undoCorridor(0), isTrue);
      expect(draft.corridors, hasLength(1));
      draft.removeCorridor(0);
      expect(draft.undoCorridor(0), isFalse);
    });

    test('replacing a drawing moves its corridors too', () {
      final (draft, _) = newDraft();
      draft.addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100);
      draft.addCorridor(0, [(x: 0.0, y: 50.0), (x: 100.0, y: 50.0)]);

      draft.replaceFloorImage(0, image: 'g2.jpg', width: 200, height: 200);

      expect(draft.corridors.single.points.last, (x: 200.0, y: 100.0));
      expect(draft.toJson()['corridors'], hasLength(1));
      draft.removeFloor(0);
      expect(draft.corridors, isEmpty);
    });

    test('tryBuild explains why an unfinished building is not ready', () {
      final (draft, _) = newDraft();

      expect(draft.tryBuild().$2, contains('"floors" must not be empty'));
    });
  });

  group('checkBuilding', () {
    BuildingMap mapOf(void Function(BuildingDraft draft) build) {
      final (draft, _) = newDraft();
      build(draft);
      return draft.tryBuild().$1!;
    }

    test('reports places that cannot be reached', () {
      final map = mapOf((d) {
        d.addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100);
        final a = d.addNode(name: 'A', type: NodeType.entry, floor: 0, x: 0, y: 0);
        final b = d.addNode(name: 'B', type: NodeType.room, floor: 0, x: 10, y: 0);
        d.addNode(name: 'Island', type: NodeType.room, floor: 0, x: 90, y: 90);
        d.togglePath(a, b);
      });

      final issues = checkBuilding(map);

      expect(issues.single.level, IssueLevel.problem);
      expect(issues.single.message, contains('Island (Ground) is not connected'));
    });

    test('warns about lifts without a match on another floor and empty floors', () {
      final map = mapOf((d) {
        d
          ..addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100)
          ..addFloor(name: 'First', image: 'f.jpg', width: 100, height: 100);
        d.addNode(name: 'Lift', type: NodeType.lift, floor: 0, x: 0, y: 0, link: 'Lift A');
      });

      final messages = checkBuilding(map).map((i) => i.message).toList();

      expect(messages, contains('First has no places yet.'));
      expect(messages.any((m) => m.startsWith('Lift is not linked to any other floor')), isTrue);
    });

    test('a building with no markers cannot be navigated', () {
      final map = mapOf((d) {
        d.addFloor(name: 'Ground', image: 'g.jpg', width: 100, height: 100);
        d.addNode(name: 'Point', type: NodeType.corridor, floor: 0, x: 0, y: 0);
      });

      expect(checkBuilding(map).map((i) => i.message), contains(startsWith('No place has a marker')));
    });
  });
}
