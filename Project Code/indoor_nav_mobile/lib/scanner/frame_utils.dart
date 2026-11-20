import 'dart:typed_data';

/// Copies a camera luminance (Y) plane into [destination] as tightly packed
/// rows, dropping the row padding many Android devices add ([bytesPerRow] can
/// be larger than [width]). The last row may be stored without its padding.
void copyLumaRows({
  required Uint8List source,
  required int bytesPerRow,
  required Uint8List destination,
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0 || bytesPerRow < width) {
    throw ArgumentError('Invalid frame geometry: ${width}x$height, $bytesPerRow bytes per row');
  }
  if (destination.length < width * height) {
    throw ArgumentError('Destination holds ${destination.length} bytes, needs ${width * height}');
  }
  final minimumSource = bytesPerRow * (height - 1) + width;
  if (source.length < minimumSource) {
    throw ArgumentError('Frame has ${source.length} bytes, needs at least $minimumSource');
  }
  if (bytesPerRow == width) {
    destination.setRange(0, width * height, source);
    return;
  }
  for (var row = 0; row < height; row++) {
    destination.setRange(row * width, row * width + width, source, row * bytesPerRow);
  }
}

/// Area of a polygon from its corners in order (shoelace formula).
/// Used to pick the closest marker when several are in view.
double polygonArea(List<(double, double)> corners) {
  var twiceArea = 0.0;
  for (var i = 0; i < corners.length; i++) {
    final (x1, y1) = corners[i];
    final (x2, y2) = corners[(i + 1) % corners.length];
    twiceArea += x1 * y2 - x2 * y1;
  }
  return twiceArea.abs() / 2;
}
