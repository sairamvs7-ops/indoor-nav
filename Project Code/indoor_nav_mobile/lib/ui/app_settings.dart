import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// App-wide preferences, saved as a small JSON file next to the buildings.
class AppSettings extends ChangeNotifier {
  AppSettings({File? file, ThemeMode themeMode = ThemeMode.system}) : _file = file, _themeMode = themeMode;

  /// Reads saved settings; missing or unreadable files give the defaults.
  static Future<AppSettings> load(File file) async {
    var mode = ThemeMode.system;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      mode = ThemeMode.values.firstWhere((m) => m.name == json['themeMode'], orElse: () => ThemeMode.system);
    } on Object {
      // First launch, or a damaged file: use the defaults.
    }
    return AppSettings(file: file, themeMode: mode);
  }

  final File? _file;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final file = _file;
    if (file != null) {
      unawaited(
        file.parent
            .create(recursive: true)
            .then((_) => file.writeAsString(jsonEncode({'themeMode': mode.name})))
            .catchError((Object _) => file),
      );
    }
  }
}

/// A menu button for choosing light, dark or system appearance.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PopupMenuButton<ThemeMode>(
        tooltip: 'Appearance',
        icon: Icon(switch (settings.themeMode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.brightness_auto_outlined,
        }),
        initialValue: settings.themeMode,
        onSelected: settings.setThemeMode,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: ThemeMode.system,
            child: ListTile(leading: Icon(Icons.brightness_auto_outlined), title: Text('Match phone')),
          ),
          PopupMenuItem(
            value: ThemeMode.light,
            child: ListTile(leading: Icon(Icons.light_mode_outlined), title: Text('Light')),
          ),
          PopupMenuItem(
            value: ThemeMode.dark,
            child: ListTile(leading: Icon(Icons.dark_mode_outlined), title: Text('Dark')),
          ),
        ],
      ),
    );
  }
}
