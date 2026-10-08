import 'dart:math' as math;

import '../models/putter_candidate.dart';
import '../models/tracked_putter.dart';

class PutterTracker {
  PutterTracker({this.maximumMovementPixels = 120.0});

  final double maximumMovementPixels;
  TrackedPutter? _previous;

  void reset() {
    _previous = null;
  }

  TrackedPutter? track({
    required int frameIndex,
    required Duration timestamp,
    required List<PutterCandidate> candidates,
  }) {
    if (candidates.isEmpty) return null;

    PutterCandidate? selected;
    final previous = _previous;

    if (previous == null) {
      for (final candidate in candidates) {
        if (selected == null || candidate.confidence > selected.confidence) {
          selected = candidate;
        }
      }
    } else {
      var nearestDistance = double.infinity;
      for (final candidate in candidates) {
        final dx = candidate.centerX - previous.centerX;
        final dy = candidate.centerY - previous.centerY;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance <= maximumMovementPixels &&
            distance < nearestDistance) {
          nearestDistance = distance;
          selected = candidate;
        }
      }
    }

    if (selected == null) return null;

    final result = TrackedPutter(
      frameIndex: frameIndex,
      timestamp: timestamp,
      centerX: selected.centerX,
      centerY: selected.centerY,
      width: selected.width,
      height: selected.height,
      confidence: selected.confidence,
    );
    _previous = result;
    return result;
  }
}
