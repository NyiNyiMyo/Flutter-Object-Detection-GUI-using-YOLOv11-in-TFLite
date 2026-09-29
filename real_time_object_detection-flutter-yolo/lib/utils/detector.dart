import 'package:dartcv4/dartcv.dart' as cv;

import '../yolo.dart';

/// Result of running detection on a single frame.
class DetectionResult {
  final List<int> classes;
  final List<List<double>> bboxes;
  final List<double> scores;

  const DetectionResult(this.classes, this.bboxes, this.scores);

  static const empty = DetectionResult([], [], []);
}

/// Runs the (expensive) raw model inference on a BGR frame.
List<List<double>> runInference(YoloModel model, cv.Mat bgrImage) {
  return model.infer(bgrImage);
}

/// Runs the (cheap) postprocessing step given a cached raw inference output.
/// Agnostic NMS is intentionally always off - there's no UI toggle for it.
DetectionResult runPostprocess(
  YoloModel model,
  List<List<double>> inferenceOutput,
  int imageWidth,
  int imageHeight, {
  required double confidenceThreshold,
  required double iouThreshold,
}) {
  final (classes, bboxes, scores) = model.postprocess(
    inferenceOutput,
    imageWidth,
    imageHeight,
    confidenceThreshold: confidenceThreshold,
    iouThreshold: iouThreshold,
    agnostic: false,
  );
  return DetectionResult(classes, bboxes, scores);
}

/// Convenience: infer + postprocess in one call, for call sites (video /
/// webcam) that don't need to cache the raw output between frames.
DetectionResult runDetection(
  YoloModel model,
  cv.Mat bgrImage, {
  required double confidenceThreshold,
  required double iouThreshold,
}) {
  final output = runInference(model, bgrImage);
  return runPostprocess(
    model,
    output,
    bgrImage.cols,
    bgrImage.rows,
    confidenceThreshold: confidenceThreshold,
    iouThreshold: iouThreshold,
  );
}
