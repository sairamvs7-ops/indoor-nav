import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'dxf_import.dart';

/// A floor drawing chosen by the user, ready to store.
class PickedBlueprint {
  const PickedBlueprint({
    required this.bytes,
    required this.extension,
    required this.width,
    required this.height,
    this.metresPerPixel,
  });

  final Uint8List bytes;
  final String extension;
  final double width;
  final double height;

  /// Known for CAD imports (from the drawing's units); null for photos.
  final double? metresPerPixel;
}

enum _Source { gallery, camera, cad }

/// Asks where the blueprint comes from (an image on the phone, a photo of a
/// printed plan, or a CAD drawing) and returns it, or null if cancelled.
Future<PickedBlueprint?> pickBlueprint(BuildContext context) async {
  final source = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Add a floor blueprint'), subtitle: Text('A clear, top-down plan of the floor')),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose an image'),
            onTap: () => Navigator.of(context).pop(_Source.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo of a printed plan'),
            onTap: () => Navigator.of(context).pop(_Source.camera),
          ),
          ListTile(
            leading: const Icon(Icons.architecture),
            title: const Text('Import a CAD drawing (DXF)'),
            subtitle: const Text('Exact walls and real scale. Ask for "Save As DXF" if you have DWG.'),
            onTap: () => Navigator.of(context).pop(_Source.cad),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  if (source == _Source.cad) return _pickDxf(context);

  // Large photos are scaled down: plenty for tapping places, and it keeps
  // shared building files small.
  final file = await ImagePicker().pickImage(
    source: source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 88,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final (width, height) = await imageSize(bytes);
  final dot = file.name.lastIndexOf('.');
  return PickedBlueprint(
    bytes: bytes,
    extension: dot < 0 ? 'jpg' : file.name.substring(dot + 1),
    width: width.toDouble(),
    height: height.toDouble(),
  );
}

Future<PickedBlueprint?> _pickDxf(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  final picked = result?.files.singleOrNull;
  if (picked == null || !context.mounted) return null;
  try {
    final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
    // DXF text is usually ANSI; fall back to Latin-1 if it isn't UTF-8.
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = latin1.decode(bytes);
    }
    final drawing = parseDxf(text);
    if (!context.mounted) return null;
    final layers = await _chooseLayers(context, drawing);
    if (layers == null) return null;
    final image = await renderDxf(drawing, layers: layers);
    return PickedBlueprint(
      bytes: image.png,
      extension: 'png',
      width: image.width.toDouble(),
      height: image.height.toDouble(),
      metresPerPixel: image.metresPerPixel,
    );
  } on DxfFormatException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return null;
  }
}

/// Lets the user untick layers that are not walls (text, furniture, title
/// block). Clutter-looking layers start unticked.
Future<Set<String>?> _chooseLayers(BuildContext context, DxfDrawing drawing) {
  final layers = drawing.layers;
  final chosen = {
    for (final name in layers.keys)
      if (!clutterLayer.hasMatch(name)) name,
  };
  if (chosen.isEmpty) chosen.addAll(layers.keys);
  return showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Which layers are walls?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                drawing.unitsGuessed
                    ? 'The file does not say its units; they were guessed from its size.'
                    : 'Scale is taken from the drawing.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final entry in layers.entries)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  subtitle: Text('${entry.value} shapes'),
                  value: chosen.contains(entry.key),
                  onChanged: (on) => setState(() => on! ? chosen.add(entry.key) : chosen.remove(entry.key)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: chosen.isEmpty ? null : () => Navigator.of(context).pop(Set.of(chosen)),
            child: const Text('Import'),
          ),
        ],
      ),
    ),
  );
}

/// Pixel size of an encoded image, without decoding all of it.
Future<(int, int)> imageSize(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return (descriptor.width, descriptor.height);
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
