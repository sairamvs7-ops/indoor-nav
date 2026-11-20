import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indoor_nav_mobile/map/map_loader.dart';

/// Serves one string for any asset key.
class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.contents);

  final String contents;
  String? requested;

  @override
  Future<ByteData> load(String key) async {
    requested = key;
    return ByteData.sublistView(Uint8List.fromList(contents.codeUnits));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads building.json from the asset bundle', () async {
    final bundle = _StringBundle(
      '{"floors":[{"level":0,"name":"G","image":"g.jpg","width":10,"height":10}],'
      '"nodes":[{"id":1,"name":"A","type":"room","floor":0,"x":1,"y":1,"marker":1}],"edges":[]}',
    );

    final map = await loadBuildingMap(bundle);

    expect(bundle.requested, defaultMapAsset);
    expect(map.nodeForMarker(1)!.name, 'A');
  });

  test('loads the real bundled map through the app asset bundle', () async {
    final map = await loadBuildingMap(rootBundle);

    expect(map.nodes, hasLength(28));
  });
}
