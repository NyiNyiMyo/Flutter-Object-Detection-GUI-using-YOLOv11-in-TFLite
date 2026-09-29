import 'package:flutter/widgets.dart';

import '../bbox.dart';
import '../labels.dart';
import 'detector.dart';

/// Builds the overlay [Bbox] widgets for a detection result, scaling box
/// coordinates from image-pixel space into on-screen widget space.
List<Widget> buildBboxWidgets(DetectionResult result, double resizeFactor) {
  final widgets = <Widget>[];
  for (int i = 0; i < result.bboxes.length; i++) {
    final box = result.bboxes[i];
    final label = labels[result.classes[i]];
    widgets.add(
      Bbox(
        box[0] * resizeFactor,
        box[1] * resizeFactor,
        box[2] * resizeFactor,
        box[3] * resizeFactor,
        label.$1,
        result.scores[i],
        label.$2,
      ),
    );
  }
  return widgets;
}
