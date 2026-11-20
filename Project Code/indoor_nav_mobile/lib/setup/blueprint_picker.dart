import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A floor drawing chosen by the user, ready to store.
class PickedBlueprint {
  const PickedBlueprint({required this.bytes, required this.extension, required this.width, required this.height});

  final Uint8List bytes;
  final String extension;
  final double width;
  final double height;
}

/// Asks where the blueprint comes from (photo of a printed plan, or an image
/// already on the phone) and returns it, or null if cancelled.
Future<PickedBlueprint?> pickBlueprint(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Add a floor blueprint'), subtitle: Text('A clear, top-down image of the floor plan')),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery or files'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo of a printed plan'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  // Large photos are scaled down: plenty for tapping places, and it keeps
  // shared building files small.
  final file = await ImagePicker().pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 88);
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
