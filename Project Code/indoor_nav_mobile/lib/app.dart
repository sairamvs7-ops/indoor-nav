import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'map/building_map.dart';
import 'navigation/navigation_controller.dart';
import 'scanner/marker_detector.dart';
import 'ui/home_screen.dart';

const _seedColor = Color(0xFF00897B);

class IndoorNavApp extends StatefulWidget {
  const IndoorNavApp({super.key, required this.loadMap, this.createDetector = MarkerDetector.new});

  /// Loads the building map once at startup. Injected so tests can supply one.
  final Future<BuildingMap> Function() loadMap;

  /// Builds the marker detector for the scanner. Injected so tests can fake it.
  final FrameDetector Function() createDetector;

  @override
  State<IndoorNavApp> createState() => _IndoorNavAppState();
}

class _IndoorNavAppState extends State<IndoorNavApp> {
  late final Future<BuildingMap> _map = widget.loadMap();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indoor Nav',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seedColor, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seedColor, brightness: Brightness.dark),
      home: FutureBuilder<BuildingMap>(
        future: _map,
        builder: (context, snapshot) {
          if (snapshot.hasError) return MapErrorScreen(error: snapshot.error!);
          final map = snapshot.data;
          if (map == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return ChangeNotifierProvider(
            create: (_) => NavigationController(map),
            child: HomeScreen(createDetector: widget.createDetector),
          );
        },
      ),
    );
  }
}

/// Shown when building.json can't be loaded, with the exact problem, so a bad
/// hand edit is easy to find.
class MapErrorScreen extends StatelessWidget {
  const MapErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is MapFormatException ? (error as MapFormatException).message : '$error';
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('The building map could not be loaded', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              SelectableText(message, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text('Fix assets/map/building.json and restart the app.', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
