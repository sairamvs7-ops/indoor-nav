import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'text_labels.dart';

/// Reads the text on a blueprint image. Behind a function type so tests and
/// platforms without text recognition can swap it out.
typedef PlanTextReader = Future<List<TextLabel>> Function(Uint8List imageBytes);

/// Reads text with ML Kit on the phone. The Latin-script model ships inside
/// the app, so this works offline. Returns one label per line of text, with
/// its box in the image's pixels.
Future<List<TextLabel>> readPlanText(Uint8List imageBytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}plan_text_${DateTime.now().microsecondsSinceEpoch}.img');
  await file.writeAsBytes(imageBytes, flush: true);
  final recognizer = TextRecognizer();
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          TextLabel(
            line.text,
            left: line.boundingBox.left,
            top: line.boundingBox.top,
            right: line.boundingBox.right,
            bottom: line.boundingBox.bottom,
          ),
    ];
  } finally {
    await recognizer.close();
    if (await file.exists()) await file.delete();
  }
}
