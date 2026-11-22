import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../map/building_map.dart';
import '../storage/building_package.dart';
import '../storage/building_repository.dart';
import 'marker_sheet.dart';

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Writes [bytes] to a temporary file and opens the share sheet for it.
Future<void> _shareBytes(Uint8List bytes, {required String fileName, required String mimeType, String? text}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: mimeType)], text: text, subject: fileName),
  );
}

/// Shares the whole building as one .via file, so anyone with the app
/// can import it and navigate.
Future<void> shareBuilding(BuildContext context, BuildingRepository repository, String id) async {
  try {
    final bytes = await exportBuilding(repository, id);
    final name = (await repository.readJson(id))['building'] as String? ?? 'building';
    await _shareBytes(
      bytes,
      fileName: packageFileName(name),
      mimeType: 'application/json',
      text: 'Via map of $name. Open the Via app, tap Import, and pick this file.',
    );
  } on MapFormatException catch (e) {
    if (context.mounted) _toast(context, 'Finish setting up the building before sharing it: ${e.message}');
  }
}

/// Builds the printable marker PDF and opens the share sheet (print, save to
/// Files, or send to a computer).
Future<void> shareMarkerPdf(BuildContext context, BuildingMap map) async {
  final bytes = await buildMarkerPdf(map);
  final fileName = '${packageFileName(map.name).replaceAll('.$packageExtension', '')}_markers.pdf';
  await _shareBytes(bytes, fileName: fileName, mimeType: 'application/pdf');
}

/// Lets the user pick a shared .via (or older .indoornav) file and imports it.
/// Returns the new building's id, or null if cancelled or invalid.
Future<String?> importBuildingFile(BuildContext context, BuildingRepository repository) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  final picked = result?.files.singleOrNull;
  if (picked == null) return null;
  try {
    final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
    final id = await importBuilding(repository, bytes);
    if (context.mounted) _toast(context, 'Building imported');
    return id;
  } on MapFormatException catch (e) {
    if (context.mounted) _toast(context, e.message);
    return null;
  }
}
