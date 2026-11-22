import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../map/aruco_markers.dart';
import '../map/building_map.dart';

/// An ArUco marker drawn on screen, with the white margin the detector needs.
class MarkerView extends StatelessWidget {
  const MarkerView({super.key, required this.markerId, this.size = 96});

  final int markerId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Marker $markerId',
      child: CustomPaint(size: Size.square(size), painter: _MarkerPainter(markerCells(markerId))),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter(this.cells);

  final List<List<bool>> cells;

  @override
  void paint(Canvas canvas, Size size) {
    // 6 cells of marker plus one cell of white margin on each side.
    final cell = size.width / 8;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final black = Paint()..color = Colors.black;
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 6; col++) {
        if (!cells[row][col]) {
          // Slight overlap avoids hairline gaps between cells.
          canvas.drawRect(Rect.fromLTWH((col + 1) * cell, (row + 1) * cell, cell + 0.5, cell + 0.5), black);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.cells != cells;
}

/// Places that need a marker stuck on the wall, lowest floor first.
List<MapNode> placesWithMarkers(BuildingMap map) {
  final order = {for (final (i, f) in map.floors.indexed) f.level: i};
  final places = map.nodes.values.where((n) => n.markerId != null).toList()
    ..sort((a, b) {
      final byFloor = order[a.floor]!.compareTo(order[b.floor]!);
      return byFloor != 0 ? byFloor : a.markerId!.compareTo(b.markerId!);
    });
  return places;
}

/// A printable PDF with one marker per A4 page, labelled with where it goes.
/// Markers print 15 cm wide, readable from a few metres away.
Future<Uint8List> buildMarkerPdf(BuildingMap map) async {
  final doc = pw.Document(title: '${map.name} markers', creator: 'Via');
  const markerSide = 15 * PdfPageFormat.cm;
  for (final place in placesWithMarkers(map)) {
    final id = place.markerId!;
    final cells = markerCells(id);
    final cell = markerSide / 6;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(2 * PdfPageFormat.cm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(map.name, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 1.5 * PdfPageFormat.cm),
            // Black cells on white; the page margin is the quiet zone.
            pw.Column(
              children: [
                for (final row in cells)
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      for (final white in row)
                        pw.Container(width: cell, height: cell, color: white ? PdfColors.white : PdfColors.black),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 1.2 * PdfPageFormat.cm),
            pw.Text('Marker $id', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Stick at: ${place.name}', style: const pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 4),
            pw.Text(
              map.floor(place.floor).name,
              style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey800),
            ),
            pw.Spacer(),
            pw.Text(
              'Keep the white border around the square. Mount at eye level, flat, in good light.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}
