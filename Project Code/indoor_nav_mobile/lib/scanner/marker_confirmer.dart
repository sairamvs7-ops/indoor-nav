/// A marker found in one camera frame. [area] is in pixels; bigger means closer.
class DetectedMarker {
  const DetectedMarker(this.id, this.area);

  final int id;
  final double area;
}

/// Decides when a marker is really there. Only markers on the map count, the
/// largest one in a frame wins, and it must win [requiredFrames] frames in a
/// row. This filters out one-frame misreads and far-away markers.
class MarkerConfirmer {
  MarkerConfirmer({required bool Function(int id) isKnown, this.requiredFrames = 2})
    : _isKnown = isKnown,
      assert(requiredFrames >= 1);

  final bool Function(int id) _isKnown;
  final int requiredFrames;

  int? _candidate;
  int _streak = 0;

  /// Feeds one frame's detections. Returns the confirmed marker id, or null.
  int? addFrame(List<DetectedMarker> markers) {
    DetectedMarker? closest;
    for (final marker in markers) {
      if (!_isKnown(marker.id)) continue;
      if (closest == null || marker.area > closest.area) closest = marker;
    }
    if (closest == null) {
      _candidate = null;
      _streak = 0;
      return null;
    }
    if (closest.id == _candidate) {
      _streak++;
    } else {
      _candidate = closest.id;
      _streak = 1;
    }
    return _streak >= requiredFrames ? closest.id : null;
  }

  /// The first marker in [markers] that is not on the map, for a hint like
  /// "marker 35 isn't part of this map".
  int? firstUnknown(List<DetectedMarker> markers) {
    for (final marker in markers) {
      if (!_isKnown(marker.id)) return marker.id;
    }
    return null;
  }

  void reset() {
    _candidate = null;
    _streak = 0;
  }
}
